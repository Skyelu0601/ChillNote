import assert from "node:assert/strict";
import test from "node:test";
import {
  handleAccountDeletion,
  type AccountDeletionLogger,
  type AccountDeletionResponse
} from "./accountDeletion.js";
import { deleteUser } from "./store.js";

class TestResponse implements AccountDeletionResponse {
  statusCode = 200;
  body: unknown;

  status(code: number): AccountDeletionResponse {
    this.statusCode = code;
    return this;
  }

  json(body: unknown): unknown {
    this.body = body;
    return this;
  }
}

function silentLogger(): AccountDeletionLogger {
  return {
    error: () => undefined,
    log: () => undefined
  };
}

test("deleteUser removes sync metadata before the User in one idempotent transaction", async () => {
  const operations: string[] = [];
  let syncLogRows = 2;
  let tombstoneRows = 3;
  let userRows = 1;
  let transactionCount = 0;

  const transaction = {
    syncLog: {
      deleteMany: async ({ where }: { where: { userId: string } }) => {
        assert.equal(where.userId, "user-1");
        operations.push("syncLog");
        const count = syncLogRows;
        syncLogRows = 0;
        return { count };
      }
    },
    hardDeleteTombstone: {
      deleteMany: async ({ where }: { where: { userId: string } }) => {
        assert.equal(where.userId, "user-1");
        operations.push("hardDeleteTombstone");
        const count = tombstoneRows;
        tombstoneRows = 0;
        return { count };
      }
    },
    user: {
      deleteMany: async ({ where }: { where: { id: string } }) => {
        assert.equal(where.id, "user-1");
        operations.push("user");
        const count = userRows;
        userRows = 0;
        return { count };
      }
    }
  };
  const database = {
    async $transaction<T>(operation: (value: typeof transaction) => Promise<T>): Promise<T> {
      transactionCount += 1;
      return operation(transaction);
    }
  };

  await deleteUser("user-1", database);
  await deleteUser("user-1", database);

  assert.equal(transactionCount, 2);
  assert.deepEqual(operations, [
    "syncLog",
    "hardDeleteTombstone",
    "user",
    "syncLog",
    "hardDeleteTombstone",
    "user"
  ]);
  assert.equal(syncLogRows, 0);
  assert.equal(tombstoneRows, 0);
  assert.equal(userRows, 0);
});

test("account deletion returns success only after business data and Auth are both deleted", async () => {
  const response = new TestResponse();
  const operations: string[] = [];

  await handleAccountDeletion({ userId: "user-1" }, response, {
    deleteBusinessData: async () => { operations.push("business"); },
    deleteAuthUser: async () => {
      operations.push("auth");
      return { error: null };
    },
    onBusinessDataDeleted: () => { operations.push("cache"); },
    logger: silentLogger()
  });

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body, { success: true });
  assert.deepEqual(operations, ["business", "cache", "auth"]);
});

test("account deletion does not report success when Supabase Auth deletion fails", async () => {
  const response = new TestResponse();
  let businessDeletionCount = 0;

  await handleAccountDeletion({ userId: "user-1" }, response, {
    deleteBusinessData: async () => { businessDeletionCount += 1; },
    deleteAuthUser: async () => ({ error: new Error("Supabase unavailable") }),
    logger: silentLogger()
  });

  assert.equal(businessDeletionCount, 1);
  assert.equal(response.statusCode, 502);
  assert.deepEqual(response.body, {
    error: "Failed to delete account",
    code: "ACCOUNT_AUTH_DELETE_FAILED",
    retryable: true
  });
  assert.notDeepEqual(response.body, { success: true });
});

test("account deletion treats a thrown Supabase Auth error as retryable failure", async () => {
  const response = new TestResponse();

  await handleAccountDeletion({ userId: "user-1" }, response, {
    deleteBusinessData: async () => undefined,
    deleteAuthUser: async () => { throw new Error("network failure"); },
    logger: silentLogger()
  });

  assert.equal(response.statusCode, 502);
  assert.deepEqual(response.body, {
    error: "Failed to delete account",
    code: "ACCOUNT_AUTH_DELETE_FAILED",
    retryable: true
  });
});

test("a retry after Auth failure safely repeats business deletion and can complete", async () => {
  let businessDeletionCount = 0;
  let authDeletionCount = 0;
  const dependencies = {
    deleteBusinessData: async () => { businessDeletionCount += 1; },
    deleteAuthUser: async () => {
      authDeletionCount += 1;
      return { error: authDeletionCount === 1 ? new Error("temporary failure") : null };
    },
    logger: silentLogger()
  };

  const firstResponse = new TestResponse();
  await handleAccountDeletion({ userId: "user-1" }, firstResponse, dependencies);
  assert.equal(firstResponse.statusCode, 502);

  const retryResponse = new TestResponse();
  await handleAccountDeletion({ userId: "user-1" }, retryResponse, dependencies);

  assert.equal(businessDeletionCount, 2);
  assert.equal(authDeletionCount, 2);
  assert.equal(retryResponse.statusCode, 200);
  assert.deepEqual(retryResponse.body, { success: true });
});

test("account deletion does not call Auth when the business-data transaction fails", async () => {
  const response = new TestResponse();
  let authCalled = false;

  await handleAccountDeletion({ userId: "user-1" }, response, {
    deleteBusinessData: async () => { throw new Error("database unavailable"); },
    deleteAuthUser: async () => {
      authCalled = true;
      return { error: null };
    },
    logger: silentLogger()
  });

  assert.equal(authCalled, false);
  assert.equal(response.statusCode, 500);
  assert.deepEqual(response.body, {
    error: "Failed to delete account",
    code: "ACCOUNT_DATA_DELETE_FAILED",
    retryable: true
  });
});

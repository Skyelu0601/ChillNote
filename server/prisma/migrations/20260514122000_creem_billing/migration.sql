ALTER TABLE "User"
ADD COLUMN "subscriptionProvider" TEXT,
ADD COLUMN "creemCustomerId" TEXT,
ADD COLUMN "creemSubscriptionId" TEXT;

CREATE UNIQUE INDEX "User_creemSubscriptionId_key" ON "User"("creemSubscriptionId");

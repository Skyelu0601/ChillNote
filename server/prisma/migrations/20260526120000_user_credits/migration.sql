-- CreateTable
CREATE TABLE IF NOT EXISTS "UserCredits" (
    "userId" TEXT NOT NULL,
    "balance" INTEGER NOT NULL DEFAULT 30,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UserCredits_pkey" PRIMARY KEY ("userId")
);

-- AddForeignKey
ALTER TABLE "UserCredits" ADD CONSTRAINT "UserCredits_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Schema of a fresh Flourish database at user_version 6 (before v7).
CREATE TABLE "accounts" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "type" TEXT NOT NULL, "balance" REAL NOT NULL DEFAULT 0.0, "currency" TEXT NOT NULL DEFAULT 'EGP', "color" INTEGER NOT NULL, "icon" TEXT NOT NULL, "created_at" INTEGER NOT NULL, CHECK (type IN ('bank', 'cash', 'ewallet', 'credit')));
CREATE TABLE "budgets" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "category_id" INTEGER NOT NULL REFERENCES categories (id) ON DELETE CASCADE, "amount" REAL NOT NULL, "period" TEXT NOT NULL, "start_date" INTEGER NOT NULL, "created_at" INTEGER NOT NULL, CHECK (period IN ('weekly', 'monthly', 'yearly')));
CREATE TABLE "categories" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "icon" TEXT NOT NULL, "color" INTEGER NOT NULL, "type" TEXT NOT NULL, "is_default" INTEGER NOT NULL DEFAULT 0 CHECK ("is_default" IN (0, 1)), "sort_order" INTEGER NOT NULL DEFAULT 0, CHECK (type IN ('income', 'expense')));
CREATE TABLE exact_balances (
      account_id INTEGER PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
      balance TEXT NOT NULL, opening TEXT NOT NULL);
CREATE TABLE finance_records (
      collection TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL,
      PRIMARY KEY(collection, id));
CREATE TABLE "goals" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "target_amount" REAL NOT NULL, "current_amount" REAL NOT NULL DEFAULT 0.0, "deadline" INTEGER NOT NULL, "account_id" INTEGER NOT NULL REFERENCES accounts (id) ON DELETE CASCADE, "color" INTEGER NOT NULL, "icon" TEXT NOT NULL, "created_at" INTEGER NOT NULL);
CREATE TABLE "recurring_transactions" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "account_id" INTEGER NOT NULL REFERENCES accounts (id) ON DELETE CASCADE, "category_id" INTEGER NOT NULL REFERENCES categories (id) ON DELETE SET NULL, "amount" REAL NOT NULL, "type" TEXT NOT NULL, "note" TEXT NULL, "frequency" TEXT NOT NULL, "next_date" INTEGER NOT NULL, "is_active" INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)), "created_at" INTEGER NOT NULL, CHECK (type IN ('income', 'expense')));
CREATE TABLE transaction_details (
      transaction_id INTEGER PRIMARY KEY REFERENCES transactions(id) ON DELETE CASCADE,
      payload TEXT NOT NULL);
CREATE TABLE "transactions" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "account_id" INTEGER NOT NULL REFERENCES accounts (id) ON DELETE CASCADE, "category_id" INTEGER NOT NULL REFERENCES categories (id) ON DELETE SET NULL, "amount" REAL NOT NULL, "type" TEXT NOT NULL, "note" TEXT NULL, "transaction_date" INTEGER NOT NULL, "linked_transaction_id" INTEGER NULL, "created_at" INTEGER NOT NULL, CHECK (type IN ('income', 'expense', 'transfer')), FOREIGN KEY (linked_transaction_id) REFERENCES transactions (id) ON DELETE SET NULL);
CREATE INDEX idx_budgets_category_id ON budgets(category_id);
CREATE INDEX idx_categories_type ON categories(type);
CREATE INDEX idx_transactions_account_id ON transactions(account_id);
CREATE INDEX idx_transactions_category_id ON transactions(category_id);
CREATE INDEX idx_transactions_linked ON transactions(linked_transaction_id);
CREATE INDEX idx_transactions_transaction_date ON transactions(transaction_date);
CREATE INDEX idx_transactions_type_date ON transactions(type, transaction_date);

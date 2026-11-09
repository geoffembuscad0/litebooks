# LiteBooks --- Features and Process Documentation

This document explains LiteBooks in everyday business language. It
describes what the system is intended to do, how users will work with
it, and how common business activities move through inventory and
accounting.

It is a living document. Features described as planned are not
necessarily implemented yet.

## 1. What is LiteBooks?

LiteBooks is an application for managing a small business's inventory
and basic accounting records.

It brings together three connected questions:

1.  **What do we have?** --- Products and stock on hand.
2.  **What happened in the business?** --- Purchases, sales, expenses,
    and payments.
3.  **How is the business doing financially?** --- Income, expenses,
    assets, liabilities, and equity.

The goal is to let a business owner record everyday activity and use
those records to understand the business.

## 2. Who uses the system?

The initial version is designed around an owner who may manage one or
more companies.

A user signs in with an account. The user can create or access companies
they own, then choose which company to manage.

Each company has separate business records. For example, products,
customers, suppliers, sales, and financial reports belonging to Company
A must not appear in Company B.

The first version is owner-only. Staff accounts, roles, and invitations
are possible future enhancements.

## 3. Main features

### 3.1 Account Management

Purpose: provide a secure way for a person to access LiteBooks.

Planned capabilities: - Register an account. - Sign in and sign out. -
Manage basic profile information. - Recover access through the supported
authentication process. - Maintain account settings.

A user account is separate from a company. One user can own multiple
companies.

### 3.2 Company Management

Purpose: let the user create and manage separate business workspaces.

Planned capabilities: - Create a company. - Edit company details. - Set
the company's currency and fiscal-year starting month. - View the
companies the user owns. - Select or switch the active company.

Company information may include its name, business code, address,
contact details, currency, and fiscal-year settings.

**Important:** selecting a company changes the workspace being viewed.
It does not grant permission by itself. The system checks that the
signed-in user is allowed to access that company.

### 3.3 Dashboard

Purpose: provide a quick overview of the selected company.

Planned information: - Number of active products. - Current stock
quantities and inventory value. - Recent purchases and sales. - Recorded
expenses. - Sales and expense summaries. - Profit and loss indicators.

Dashboard figures should come from the company's underlying records.
They should not be separately typed in as totals.

### 3.4 Inventory

Purpose: maintain the products a company buys, stores, and sells.

Planned capabilities: - Create and update product records. - Organize
products into categories. - Define units of measure, such as pieces,
boxes, kilograms, or liters. - Store SKU and barcode information where
applicable. - Set a default cost, selling price, and reorder level. -
Review stock movement history. - Review stock on hand and inventory
valuation.

A product record describes an item. It is not the permanent record of
how many units are currently in stock.

Stock changes are recorded as inventory movements. The system calculates
stock on hand by adding incoming movements and subtracting outgoing
movements.

Examples of incoming movements: - Opening stock entered when setting up
the system. - Purchases from suppliers. - Positive inventory
adjustments.

Examples of outgoing movements: - Sales to customers. - Negative
inventory adjustments. - Damaged or missing stock.

The planned inventory costing method is **perpetual weighted average
cost**. In simple terms, the system recalculates the average cost of
stock as new stock is received. When stock is sold, the current average
cost is used to calculate the cost of the goods sold.

### 3.5 Contacts

Purpose: keep customer and supplier information in one place.

A contact can be: - A customer - A supplier - Both a customer and a
supplier

Planned details include name, contact person, email, phone, tax number,
billing address, shipping address, and notes.

Contacts are stored within a company, so each company maintains its own
customer and supplier list.

### 3.6 Transactions

Purpose: record the business activities that affect money and, in some
cases, inventory.

The initial transaction types are:

**Purchase** - Records products or other items acquired from a
supplier. - Product lines can increase inventory when the purchase is
posted. - The purchase may be paid immediately or left partly or fully
unpaid.

**Sale** - Records products sold to a customer. - Product lines reduce
inventory when the sale is posted. - The sale may be paid immediately or
left partly or fully unpaid.

**Expense** - Records operating costs such as rent, utilities, internet,
or office supplies. - Expense lines are linked to an appropriate expense
account. - An expense does not automatically increase or decrease
product stock.

Transactions are expected to support draft, posted, and void states.

-   **Draft:** being prepared; it does not yet affect official inventory
    or accounting balances.
-   **Posted:** confirmed and included in the relevant records and
    reports.
-   **Void:** marked as void according to the application's controlled
    correction process.

A posted transaction should not be casually edited or deleted.
Corrections should preserve an audit trail.

### 3.7 Payments

Purpose: record money received from customers or paid to suppliers and
other parties.

A payment records: - The related transaction. - The payment date. - The
amount. - The payment method. - The cash or bank account used. - An
optional reference and note.

The system should support partial payments. For example, a customer may
pay part of an invoice today and the remainder later.

The amount paid against a transaction is calculated from its payment
records. The system should not rely on a manually maintained payment
status that can become inconsistent with the actual payments.

### 3.8 Accounting

Purpose: translate business activity into organized financial records.

The accounting area is based on double-entry bookkeeping.

**Chart of Accounts**

The Chart of Accounts is the company's categorized list of financial
accounts. Examples include:

  Account category   Examples
  ------------------ ---------------------------------------------------
  Assets             Cash, Bank, Accounts Receivable, Inventory
  Liabilities        Accounts Payable, Loans Payable
  Equity             Owner's Capital, Retained Earnings
  Revenue            Sales Revenue, Service Revenue
  Expenses           Rent Expense, Utilities Expense, Salaries Expense

Each company has its own Chart of Accounts.

**Journal Entries**

A journal entry records the financial effect of an event. Each entry
contains one or more debit lines and one or more credit lines.

The total debit amount must always equal the total credit amount before
an entry can be posted.

Example: a cash sale of ₱5,000, where the goods sold cost the business
₱3,000:

  Account                     Debit       Credit
  -------------------- ------------ ------------
  Cash                       ₱5,000 
  Sales Revenue                           ₱5,000
  Cost of Goods Sold         ₱3,000 
  Inventory                               ₱3,000
  **Total**              **₱8,000**   **₱8,000**

This example records both the sale and the cost of the inventory that
left the business.

**General Ledger**

The General Ledger shows the activity recorded in each account. It helps
answer questions such as: - How much cash came in and went out? - What
is the current Accounts Receivable balance? - How much has been spent on
rent? - What entries make up the Inventory account balance?

### 3.9 Financial Reports

Purpose: help the owner understand the company's financial performance
and position.

Planned reports include:

**Profit and Loss Statement** - Shows revenue and expenses over a
selected period. - Calculates the resulting profit or loss.

**Balance Sheet** - Shows assets, liabilities, and equity at a
particular date. - Follows the accounting equation:

`Assets = Liabilities + Equity`

**Inventory Summary** - Shows stock quantities and estimated inventory
value by product.

**General Ledger and Trial Balance** - The General Ledger shows
account-level activity. - The Trial Balance lists account balances and
helps confirm that total debits and credits agree.

Reports should be based on posted accounting records and appropriately
calculated inventory records.

## 4. Everyday process flows

The following examples explain how a user is expected to work in
LiteBooks. Exact screen layouts and some detailed rules will be
finalized during implementation.

### 4.1 First-time setup

1.  The user registers for a LiteBooks account.
2.  The user signs in.
3.  The user creates a company and enters its basic details.
4.  The system prepares the company's initial setup, including its Chart
    of Accounts.
5.  The user adds product categories and units of measure.
6.  The user adds products.
7.  If the business already has stock, the user records opening stock
    and its starting cost.
8.  The user can then begin recording purchases, sales, and expenses.

**In plain language:** first tell LiteBooks who you are, then which
business you are managing, then what that business sells or stores.

### 4.2 Switching companies

1.  The user signs in.
2.  The user selects a company from the company switcher.
3.  LiteBooks loads the selected company's products, contacts,
    transactions, and reports.
4.  If the user switches to another company, the business information on
    screen changes to that company's records.

**Important:** company data remains separate. Switching companies should
never combine their inventory or financial records.

### 4.3 Recording a purchase

Example: a company purchases 20 units of a product from a supplier.

1.  The user opens Purchases or Transactions.
2.  The user selects the supplier.
3.  The user adds the product and quantity.
4.  The user enters the purchase price and any applicable discount or
    tax.
5.  The user saves the purchase as a draft if it is not ready to
    confirm.
6.  When the details are correct, the user posts the purchase.
7.  LiteBooks records the purchase and creates an incoming inventory
    movement.
8.  The inventory quantity and weighted average cost are updated.
9.  The accounting records are generated.
10. If the purchase is paid, the user records a payment. If it is
    unpaid, the amount remains payable.

**Result:** stock increases, the purchase is recorded, and the financial
records reflect the purchase and any payment.

### 4.4 Recording a sale

Example: a company sells 5 units of a product to a customer.

1.  The user opens Sales or Transactions.
2.  The user selects the customer.
3.  The user adds the product and quantity.
4.  LiteBooks checks whether sufficient stock is available.
5.  The user reviews the price, discount, and tax.
6.  The user saves a draft or posts the sale.
7.  When posted, LiteBooks records the sale and creates an outgoing
    inventory movement.
8.  The system calculates the cost of the goods sold using the
    applicable inventory cost.
9.  The accounting records recognize revenue and the cost of goods sold.
10. The user records any payment received. An unpaid balance remains
    receivable.

**Result:** stock decreases, revenue is recorded, the cost of the sold
goods is recognized, and any unpaid amount can be tracked.

### 4.5 Recording an operating expense

Example: the company pays ₱2,000 for an internet bill.

1.  The user opens Expenses or Transactions.
2.  The user enters the expense details.
3.  The user selects the appropriate expense account.
4.  The user enters the amount and date.
5.  The user saves or posts the expense.
6.  If paid, the user records the payment account and method.
7.  LiteBooks records the expense in the accounting records.

**Result:** the expense appears in the company's financial activity. It
does not change product stock unless the transaction is specifically
recorded as an inventory purchase.

### 4.6 Recording a customer or supplier payment

1.  The user opens the related sale, purchase, or expense.
2.  The user chooses to record a payment.
3.  The user enters the payment date, amount, method, and cash or bank
    account.
4.  LiteBooks records the payment.
5.  The amount paid is added to the payments already recorded for that
    transaction.
6.  The remaining amount due is recalculated.

**Example:** an invoice is ₱10,000. The customer pays ₱4,000 first. The
remaining balance is ₱6,000. When the customer pays the remaining
₱6,000, the invoice is fully paid.

### 4.7 Recording opening stock

When a business starts using LiteBooks, it may already have products
in its storage area.

1.  The user creates the product records.
2.  The user enters the quantity currently on hand.
3.  The user enters the appropriate starting unit cost.
4.  The user records an opening-stock movement.
5.  LiteBooks includes the opening quantity and value in inventory
    records.
6.  The corresponding opening accounting balance must be established as
    part of the company's accounting setup.

**Result:** the system starts with a recorded quantity and value rather
than treating existing stock as a new purchase.

### 4.8 Correcting an inventory count

Suppose the system shows 50 units, but a physical count finds only 48.

1.  The user performs a physical stock count.
2.  The user compares the physical quantity with the system quantity.
3.  The user records an adjustment of 2 units out.
4.  The user enters a reason, such as damage, loss, or counting
    correction.
5.  LiteBooks records the adjustment and its financial effect.

**Result:** the inventory record reflects the verified stock count,
while the adjustment history remains available for review.

## 5. How inventory and accounting work together

Inventory and accounting are related, but they answer different
questions.

-   Inventory movements answer: **How many units came in or went out,
    and what did they cost?**
-   Journal entries answer: **Which financial accounts increased or
    decreased because of the activity?**

For example, posting a sale has two important effects:

1.  The product quantity decreases.
2.  The accounting records recognize sales revenue and the cost of the
    inventory sold.

A payment is another event. Receiving cash from a customer changes the
cash and receivable balances; it does not create a second sale.

Keeping these events distinct helps avoid counting the same revenue or
expense twice.

## 6. Important terms in everyday language

  -----------------------------------------------------------------------
  Term                                Plain-language meaning
  ----------------------------------- -----------------------------------
  Company                             The business workspace whose
                                      records are being managed.

  Product                             An item the company buys, stores,
                                      or sells.

  Category                            A way to group similar products.

  Unit of measure                     How a product is counted, such as
                                      piece, box, or kilogram.

  SKU                                 A company's internal code for
                                      identifying a product.

  Contact                             A customer, supplier, or both.

  Purchase                            A record of goods or services
                                      acquired by the company.

  Sale                                A record of goods or services sold
                                      by the company.

  Expense                             A cost incurred while operating the
                                      business.

  Inventory movement                  A record of stock entering or
                                      leaving inventory.

  Weighted average cost               An average unit cost based on the
                                      quantity and cost of stock
                                      available.

  Chart of Accounts                   The organized list of financial
                                      accounts used by a company.

  Debit                               One side of an accounting entry;
                                      its effect depends on the account
                                      type.

  Credit                              The other side of an accounting
                                      entry; its effect depends on the
                                      account type.

  Journal entry                       A record of the debit and credit
                                      effects of a business event.

  General Ledger                      The detailed history of activity in
                                      each financial account.

  Accounts Receivable                 Money customers still owe the
                                      company.

  Accounts Payable                    Money the company still owes
                                      suppliers or other parties.

  Cost of Goods Sold (COGS)           The cost to the business of the
                                      products that were sold.

  Profit                              Revenue remaining after the
                                      relevant expenses are deducted.

  Draft                               A record being prepared and not yet
                                      officially posted.

  Posted                              A confirmed record included in
                                      official business and accounting
                                      records.
  -----------------------------------------------------------------------

## 7. Planned development stages

The project will be developed in manageable stages.

  -----------------------------------------------------------------------
  Stage                   Focus                   Main outcome
  ----------------------- ----------------------- -----------------------
  1                       Project and development React, FastAPI,
                          setup                   Supabase, and GitHub
                                                  working together.

  2                       Core database structure Tables for profiles,
                                                  companies, products,
                                                  contacts, transactions,
                                                  inventory, and
                                                  accounting.

  3                       Database integrity and  Shared database
                          defaults                functions, validation
                                                  safeguards, and default
                                                  Chart of Accounts.

  4                       Database security       Authentication
                                                  integration, company
                                                  ownership checks, and
                                                  RLS policies.

  5                       Account and company     Registration, company
                          workflows               creation, company
                                                  selection, and company
                                                  switching.

  6                       Inventory workflows     Categories, units,
                                                  products, opening
                                                  stock, movements, and
                                                  stock valuation.

  7                       Transaction workflows   Purchases, sales,
                                                  expenses, and payments.

  8                       Accounting workflows    Journal generation,
                                                  posting, General
                                                  Ledger, and Trial
                                                  Balance.

  9                       Financial reports       Profit and Loss,
                                                  Balance Sheet, and
                                                  inventory reports.

  10                      Dashboard and           Business summaries,
                          refinement              usability improvements,
                                                  testing, and bug fixes.
  -----------------------------------------------------------------------

Stages may overlap when a feature requires supporting work from another
stage.

## 8. Controls and safeguards

The system is intended to preserve trustworthy business records.

-   Each business record belongs to a company.
-   A user must be authorized to access a company before its data is
    returned.
-   Draft transactions should not affect official stock or accounting
    balances.
-   Posting should update related records together, so partial posting
    does not leave inventory and accounting inconsistent.
-   A sale should not reduce stock below zero unless a deliberate
    business rule later permits it.
-   Journal entries must balance before posting.
-   Posted accounting records should retain their audit history.
-   Corrections should use controlled reversals or adjustments.
-   Financial reports should use posted records and clearly defined
    reporting dates.

These safeguards will be implemented and tested as development
progresses.

## 9. Current implementation status

The project has been set up with a React/TypeScript frontend, a FastAPI
backend, and a hosted Supabase project.

The initial database design has been prepared in batches through:

-   Profiles and companies
-   Categories, units of measure, and products
-   Contacts and accounts
-   Transactions, transaction items, and payments
-   Inventory movements
-   Journal entries and journal lines

The developer has reported successful Supabase CLI dry-run checks
through the journal-entry batch. A dry run is a preview, not proof that
the migrations have been applied to the hosted database.

The next planned work is to complete database helper functions and
triggers, seed each new company with a suitable default Chart of
Accounts, and implement and test Row Level Security policies.

## 10. Scope boundaries and future possibilities

The first release is intended to focus on the essential inventory and
accounting workflows.

Potential future enhancements may include: - Multiple staff users and
role-based permissions. - Customer and supplier statements. - Purchase
and sales returns. - More advanced tax handling. - Bank
reconciliation. - Document and receipt attachments. - Stock transfers
between locations. - More detailed financial and operational reports.

These are possibilities, not commitments for the initial release.

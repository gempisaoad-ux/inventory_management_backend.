# Inventory Management System — DBMS Activity

## 1. Requirements
- Node.js (18 or newer recommended)
- PostgreSQL
- Postman

## 2. Create the database
Open pgAdmin Query Tool or psql and run:
```sql
CREATE DATABASE inventory_db;
```
Select/connect to `inventory_db`, then open and execute `sql/schema.sql`. This creates 5 related tables, sample records, 2 SQL functions, and 3 stored procedures.

## 3. Configure the backend
In this project folder:
```bash
npm install
```
Copy `.env.example` to `.env`, then edit `DB_PASSWORD` to match your PostgreSQL password. Keep the database name as `inventory_db` unless you used another name.

## 4. Start the API
```bash
npm start
```
Expected message: `Inventory API running at http://localhost:3000`

## 5. Import the Postman collection
In Postman, click **Import**, select `postman/Inventory_Management_API.postman_collection.json`, then send requests in order.

Base URL: `http://localhost:3000`

### API endpoints
| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/products` | List products and stock |
| GET | `/api/products/1/stock-value` | Executes SQL function 1 |
| GET | `/api/sales/1/total` | Executes SQL function 2 (use a sale ID created first) |
| POST | `/api/sales` | Executes `create_sale()` |
| POST | `/api/products/1/restock` | Executes `restock_product()` |
| POST | `/api/sales/1/cancel` | Executes `cancel_sale()` |
| GET | `/api/sales/1` | Verify sale details and total |

## 6. Suggested demonstration order
1. `GET /api/products` — record the original stock for product 1.
2. `GET /api/products/1/stock-value` — show the SQL function result.
3. `POST /api/sales` with `{"customer_id":1,"product_id":1,"quantity":2}` — show a successful stored procedure call. Save the returned sale ID.
4. `GET /api/products` — verify product 1 stock decreased by 2.
5. `GET /api/sales/{sale_id}/total` — show the second SQL function.
6. `POST /api/products/1/restock` with `{"quantity":5}` — show stock increase.
7. `POST /api/sales/{sale_id}/cancel` — show sale cancellation and stock restoration.
8. Run the negative tests below and capture the error responses.

## 7. Negative tests
- Invalid quantity: `POST /api/sales` with quantity `0`. Expected: HTTP 400 and database validation message.
- Insufficient stock: `POST /api/sales` with product 1 and quantity `99999`. Expected: HTTP 400; no sale should be saved and stock should remain unchanged.
- Missing product: `GET /api/products/9999/stock-value`. Expected: HTTP 404.
- Optional: attempt to cancel the same sale twice. Expected: HTTP 400 because it is already cancelled.

## 8. Business rules implemented in PostgreSQL
1. Sale quantity must be greater than zero (`create_sale`).
2. A sale cannot exceed available stock (`create_sale`).
3. A sale must reference an existing customer and product (`create_sale` and foreign keys).
4. Restock quantity must be greater than zero (`restock_product`).
5. A cancelled sale cannot be cancelled again (`cancel_sale`).
6. Cancelling a completed sale restores the sold product quantities (`cancel_sale`).

## 9. Transaction safety
Each `CALL` is executed as one PostgreSQL statement. If a procedure raises an exception, PostgreSQL rolls back the changes made by that statement. In `create_sale`, the sale header, sale item, and stock deduction therefore succeed together or fail together.

## 10. Submission checklist
- `sql/schema.sql`
- `server.js`, `package.json`, `.env.example`
- `postman/Inventory_Management_API.postman_collection.json`
- `README.md` (use as the basis for your documentation)
- Screenshots of successful function calls, successful sale, stock verification, and failed tests.

Do not submit your real `.env` file or database password.

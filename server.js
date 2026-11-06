require("dotenv").config();
const express = require("express");
const { Pool } = require("pg");

const app = express();
app.use(express.json());

const pool = new Pool({
  host: process.env.DB_HOST || "localhost",
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME || "inventory_db",
  user: process.env.DB_USER || "postgres",
  password: process.env.DB_PASSWORD,
});

function sendDbError(res, error) {
  console.error(error.message);
  const status = error.code === "P0002" ? 404 : 400;
  res.status(status).json({
    success: false,
    message: error.message || "Database operation failed",
  });
}

app.get("/", (_req, res) => {
  res.json({ message: "Inventory Management API is running" });
});

// GET all products and their current stock.
app.get("/api/products", async (_req, res) => {
  try {
    const result = await pool.query(`
      SELECT p.product_id, p.product_name, c.category_name,
             p.unit_price, p.stock_quantity
      FROM products p
      JOIN categories c ON c.category_id = p.category_id
      ORDER BY p.product_id
    `);
    res.json({ success: true, data: result.rows });
  } catch (error) {
    sendDbError(res, error);
  }
});

// FUNCTION API: calls get_product_stock_value() inside PostgreSQL.
app.get("/api/products/:id/stock-value", async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ success: false, message: "Product ID must be a positive integer" });
    }
    const result = await pool.query(
      "SELECT get_product_stock_value($1) AS stock_value",
      [id]
    );
    res.json({ success: true, product_id: id, stock_value: result.rows[0].stock_value });
  } catch (error) {
    sendDbError(res, error);
  }
});

// FUNCTION API: calls calculate_sale_total() inside PostgreSQL.
app.get("/api/sales/:id/total", async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ success: false, message: "Sale ID must be a positive integer" });
    }
    const result = await pool.query(
      "SELECT calculate_sale_total($1) AS sale_total",
      [id]
    );
    res.json({ success: true, sale_id: id, sale_total: result.rows[0].sale_total });
  } catch (error) {
    sendDbError(res, error);
  }
});

// PROCEDURE API: PostgreSQL validates customer, product, quantity, and stock.
app.post("/api/sales", async (req, res) => {
  const { customer_id, product_id, quantity } = req.body;
  if (![customer_id, product_id, quantity].every(Number.isInteger)) {
    return res.status(400).json({
      success: false,
      message: "customer_id, product_id, and quantity must be integers",
    });
  }

  try {
    const result = await pool.query(
      "CALL create_sale($1, $2, $3, NULL::INTEGER)",
      [customer_id, product_id, quantity]
    );
    // PostgreSQL CALL returns the INOUT parameter as a result row.
    const saleId = result.rows[0]?.p_sale_id;
    res.status(201).json({
      success: true,
      message: "Sale completed and stock updated",
      sale_id: saleId,
    });
  } catch (error) {
    sendDbError(res, error);
  }
});

// PROCEDURE API: adds stock using restock_product().
app.post("/api/products/:id/restock", async (req, res) => {
  const productId = Number(req.params.id);
  const { quantity } = req.body;

  if (!Number.isInteger(productId) || productId <= 0 || !Number.isInteger(quantity)) {
    return res.status(400).json({ success: false, message: "Use a valid product ID and integer quantity" });
  }

  try {
    await pool.query("CALL restock_product($1, $2)", [productId, quantity]);
    const updated = await pool.query(
      "SELECT product_id, product_name, stock_quantity FROM products WHERE product_id = $1",
      [productId]
    );
    res.json({ success: true, message: "Stock successfully restocked", data: updated.rows[0] });
  } catch (error) {
    sendDbError(res, error);
  }
});

// PROCEDURE API: cancels a sale and restores stock using cancel_sale().
app.post("/api/sales/:id/cancel", async (req, res) => {
  const saleId = Number(req.params.id);
  if (!Number.isInteger(saleId) || saleId <= 0) {
    return res.status(400).json({ success: false, message: "Sale ID must be a positive integer" });
  }

  try {
    await pool.query("CALL cancel_sale($1)", [saleId]);
    res.json({ success: true, message: "Sale cancelled and stock restored", sale_id: saleId });
  } catch (error) {
    sendDbError(res, error);
  }
});

app.get("/api/sales/:id", async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT s.sale_id, s.customer_id, c.customer_name, s.sale_date, s.status,
             calculate_sale_total(s.sale_id) AS sale_total
      FROM sales s
      JOIN customers c ON c.customer_id = s.customer_id
      WHERE s.sale_id = $1
    `, [Number(req.params.id)]);
    if (!result.rowCount) return res.status(404).json({ success: false, message: "Sale not found" });
    res.json({ success: true, data: result.rows[0] });
  } catch (error) {
    sendDbError(res, error);
  }
});

const port = Number(process.env.PORT || 3000);
app.listen(port, () => console.log(`Inventory API running at http://localhost:${port}`));

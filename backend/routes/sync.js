const express = require('express');
const { query, getConnection } = require('../db');
const router = express.Router();

router.post('/push', async (req, res) => {
  const {
    businessId,
    products,
    suppliers,
    sales,
    saleItems,
    purchaseOrders,
    inventoryMovements,
    damageReports,
  } = req.body;

  const resolvedBusinessId = businessId || req.headers['x-business-id'] || req.auth?.businessId || null;

  if (!resolvedBusinessId) {
    return res.status(400).json({ success: false, message: 'businessId is required.' });
  }

  const connection = await getConnection();
  try {
    await connection.beginTransaction();

    const stats = {
      products: 0,
      suppliers: 0,
      sales: 0,
      saleItems: 0,
      purchaseOrders: 0,
      inventoryMovements: 0,
      damageReports: 0,
    };

    if (Array.isArray(products)) {
      for (const product of products) {
        await connection.execute(
          `INSERT INTO products
            (id, business_id, barcode, name, category, selling_price, quantity, image_path, low_stock_threshold, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              barcode = VALUES(barcode),
              name = VALUES(name),
              category = VALUES(category),
              selling_price = VALUES(selling_price),
              quantity = VALUES(quantity),
              image_path = VALUES(image_path),
              low_stock_threshold = VALUES(low_stock_threshold),
              updated_at = VALUES(updated_at)`,
          [
            product.id,
            resolvedBusinessId,
            product.barcode,
            product.name,
            product.category,
            product.selling_price,
            product.quantity,
            product.image_path,
            product.low_stock_threshold,
            product.created_at,
            product.updated_at,
          ],
        );
        stats.products += 1;
      }
    }

    if (Array.isArray(suppliers)) {
      for (const supplier of suppliers) {
        await connection.execute(
          `INSERT INTO suppliers
            (id, business_id, name, contact_person, email, phone, address, notes, is_active, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              name = VALUES(name),
              contact_person = VALUES(contact_person),
              email = VALUES(email),
              phone = VALUES(phone),
              address = VALUES(address),
              notes = VALUES(notes),
              is_active = VALUES(is_active)`,
          [
            supplier.id,
            resolvedBusinessId,
            supplier.name,
            supplier.contact_person,
            supplier.email,
            supplier.phone,
            supplier.address,
            supplier.notes,
            supplier.is_active ? 1 : 0,
            supplier.created_at,
          ],
        );
        stats.suppliers += 1;
      }
    }

    if (Array.isArray(sales)) {
      for (const sale of sales) {
        await connection.execute(
          `INSERT INTO sales
            (id, business_id, cashier_id, cashier_name, customer_name, customer_id, payment_method, status, subtotal, discount, total_amount, amount_paid, change_amount, item_count, datetime, notes, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              cashier_name = VALUES(cashier_name),
              customer_name = VALUES(customer_name),
              customer_id = VALUES(customer_id),
              payment_method = VALUES(payment_method),
              status = VALUES(status),
              subtotal = VALUES(subtotal),
              discount = VALUES(discount),
              total_amount = VALUES(total_amount),
              amount_paid = VALUES(amount_paid),
              change_amount = VALUES(change_amount),
              item_count = VALUES(item_count),
              datetime = VALUES(datetime),
              notes = VALUES(notes)`,
          [
            sale.id,
            resolvedBusinessId,
            sale.cashier_id,
            sale.cashier_name,
            sale.customer_name,
            sale.customer_id ?? sale.customerId ?? null,
            sale.payment_method,
            sale.status,
            sale.subtotal,
            sale.discount,
            sale.total_amount,
            sale.amount_paid,
            sale.change_amount,
            sale.item_count,
            sale.datetime,
            sale.notes,
            sale.created_at,
          ],
        );
        stats.sales += 1;
      }
    }

    if (Array.isArray(saleItems)) {
      for (const item of saleItems) {
        await connection.execute(
          `INSERT INTO sale_items
            (sale_id, business_id, product_id, product_name, quantity, unit_price, discount, subtotal, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              product_name = VALUES(product_name),
              quantity = VALUES(quantity),
              unit_price = VALUES(unit_price),
              discount = VALUES(discount),
              subtotal = VALUES(subtotal)`,
          [
            item.sale_id,
            resolvedBusinessId,
            item.product_id,
            item.product_name,
            item.quantity,
            item.unit_price,
            item.discount,
            item.subtotal,
            item.created_at,
          ],
        );
        stats.saleItems += 1;
      }
    }

    if (Array.isArray(purchaseOrders)) {
      for (const order of purchaseOrders) {
        await connection.execute(
          `INSERT INTO purchase_orders
            (id, business_id, supplier_id, order_number, order_date, expected_delivery, status, total_amount, notes, created_by, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              supplier_id = VALUES(supplier_id),
              order_number = VALUES(order_number),
              order_date = VALUES(order_date),
              expected_delivery = VALUES(expected_delivery),
              status = VALUES(status),
              total_amount = VALUES(total_amount),
              notes = VALUES(notes),
              created_by = VALUES(created_by)`,
          [
            order.id,
            resolvedBusinessId,
            order.supplier_id,
            order.order_number,
            order.order_date,
            order.expected_delivery,
            order.status,
            order.total_amount,
            order.notes,
            order.created_by,
            order.created_at,
          ],
        );
        stats.purchaseOrders += 1;
      }
    }

    if (Array.isArray(inventoryMovements)) {
      for (const movement of inventoryMovements) {
        await connection.execute(
          `INSERT INTO inventory_movements
            (id, business_id, product_id, product_name, movement_type, quantity, reference, notes, performed_by, timestamp, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              product_name = VALUES(product_name),
              movement_type = VALUES(movement_type),
              quantity = VALUES(quantity),
              reference = VALUES(reference),
              notes = VALUES(notes),
              performed_by = VALUES(performed_by),
              timestamp = VALUES(timestamp)`,
          [
            movement.id,
            resolvedBusinessId,
            movement.product_id,
            movement.product_name,
            movement.movement_type,
            movement.quantity,
            movement.reference,
            movement.notes,
            movement.performed_by,
            movement.timestamp,
            movement.created_at,
          ],
        );
        stats.inventoryMovements += 1;
      }
    }

    if (Array.isArray(damageReports)) {
      for (const report of damageReports) {
        await connection.execute(
          `INSERT INTO damage_reports
            (id, business_id, product_id, product_name, quantity, damage_type, description, reported_by, reported_at, status, resolution_notes, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              product_name = VALUES(product_name),
              quantity = VALUES(quantity),
              damage_type = VALUES(damage_type),
              description = VALUES(description),
              reported_by = VALUES(reported_by),
              reported_at = VALUES(reported_at),
              status = VALUES(status),
              resolution_notes = VALUES(resolution_notes)`,
          [
            report.id,
            resolvedBusinessId,
            report.product_id,
            report.product_name,
            report.quantity,
            report.damage_type,
            report.description,
            report.reported_by,
            report.reported_at,
            report.status,
            report.resolution_notes,
            report.created_at,
          ],
        );
        stats.damageReports += 1;
      }
    }

    await connection.commit();
    return res.json({ success: true, stats });
  } catch (error) {
    await connection.rollback();
    console.error('Sync /push error:', error);
    return res.status(500).json({ success: false, message: 'Failed to push sync payload to backend.' });
  } finally {
    connection.release();
  }
});

router.get('/pull', async (req, res) => {
  const businessId = req.query.businessId || req.query.business_id || req.headers['x-business-id'] || req.auth?.businessId || null;
  if (!businessId) {
    return res.status(400).json({ success: false, message: 'businessId query parameter is required.' });
  }

  try {
    const [products, suppliers, sales, saleItems, purchaseOrders, inventoryMovements, damageReports] = await Promise.all([
      query('SELECT * FROM products WHERE business_id = ?', [businessId]),
      query('SELECT * FROM suppliers WHERE business_id = ?', [businessId]),
      query('SELECT * FROM sales WHERE business_id = ?', [businessId]),
      query('SELECT * FROM sale_items WHERE business_id = ?', [businessId]),
      query('SELECT * FROM purchase_orders WHERE business_id = ?', [businessId]),
      query('SELECT * FROM inventory_movements WHERE business_id = ?', [businessId]),
      query('SELECT * FROM damage_reports WHERE business_id = ?', [businessId]),
    ]);

    return res.json({
      success: true,
      products,
      suppliers,
      sales,
      saleItems,
      purchaseOrders,
      inventoryMovements,
      damageReports,
    });
  } catch (error) {
    console.error('Sync /pull error:', error);
    return res.status(500).json({ success: false, message: 'Failed to pull sync payload from backend.' });
  }
});

module.exports = router;

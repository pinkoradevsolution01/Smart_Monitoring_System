const express = require('express');
const { query, getConnection } = require('../db');
const router = express.Router();
const SYNC_ROLES = new Set(['owner', 'admin', 'manager']);

async function resolveAuthenticatedBusiness(req) {
  const auth = req.auth;
  if (!auth?.userId || !auth?.businessId || !SYNC_ROLES.has(String(auth.role || '').toLowerCase())) {
    return { status: 401, message: 'A valid owner session is required for synchronization.' };
  }

  const rows = await query(
    `SELECT u.business_id FROM users u INNER JOIN businesses b ON b.id = u.business_id
      WHERE u.id = ? AND u.business_id = ? AND u.is_active = 1 AND b.is_active = 1 LIMIT 1`,
    [auth.userId, auth.businessId],
  );
  if (!rows.length) return { status: 403, message: 'The account or business is inactive.' };
  return { businessId: rows[0].business_id };
}

function hasMismatchedRecordBusiness(payload, businessId) {
  const collections = ['users', 'customers', 'loyaltyLedger', 'cameras', 'cctvTimestamps', 'attendanceEntries', 'attendanceLeaves', 'attendanceArchive', 'activityLogs', 'products', 'suppliers', 'sales', 'saleItems', 'purchaseOrders', 'purchaseOrderItems', 'inventoryMovements', 'damageReports'];
  for (const name of collections) {
    if (!Array.isArray(payload[name])) continue;
    for (const record of payload[name]) {
      const recordBusinessId = record?.business_id || record?.businessId;
      if (recordBusinessId && String(recordBusinessId) !== String(businessId)) return name;
    }
  }
  return null;
}

router.post('/push', async (req, res) => {
  const {
    businessId,
    users,
    customers,
    loyaltyLedger,
    cameras,
    cctvTimestamps,
    attendanceEntries,
    attendanceLeaves,
    attendanceSchedule,
    attendanceArchive,
    activityLogs,
    products,
    suppliers,
    sales,
    saleItems,
    purchaseOrders,
    purchaseOrderItems,
    inventoryMovements,
    damageReports,
  } = req.body;

  const authenticated = await resolveAuthenticatedBusiness(req);
  if (!authenticated.businessId) {
    return res.status(authenticated.status).json({ success: false, message: authenticated.message });
  }
  const resolvedBusinessId = authenticated.businessId;
  const submittedBusinessId = businessId || req.headers['x-business-id'];
  if (submittedBusinessId && String(submittedBusinessId) !== String(resolvedBusinessId)) {
    return res.status(403).json({ success: false, message: 'Sync business does not match the signed-in owner.' });
  }
  const mismatchedCollection = hasMismatchedRecordBusiness(req.body, resolvedBusinessId);
  if (mismatchedCollection) {
    return res.status(403).json({ success: false, message: `Sync payload contains records for another business (${mismatchedCollection}).` });
  }
  // A deactivated subscriber's local client may still retry a queued payload.
  // Do not recreate child records for a business that was intentionally purged.
  const existingBusiness = await query(
    'SELECT id FROM businesses WHERE id = ? LIMIT 1',
    [resolvedBusinessId],
  );
  if (!existingBusiness.length) {
    return res.json({
      success: true,
      skipped: true,
      reason: 'business_cancelled',
      message: 'Sync skipped because the business is no longer active.',
    });
  }

  const connection = await getConnection();
  try {
    await connection.beginTransaction();

    const stats = {
      users: 0,
      customers: 0,
      loyaltyLedger: 0,
      cameras: 0,
      cctvTimestamps: 0,
      attendanceEntries: 0,
      attendanceLeaves: 0,
      attendanceSchedule: 0,
      attendanceArchive: 0,
      activityLogs: 0,
      products: 0,
      suppliers: 0,
      sales: 0,
      saleItems: 0,
      purchaseOrders: 0,
      purchaseOrderItems: 0,
      inventoryMovements: 0,
      damageReports: 0,
    };

    if (Array.isArray(users)) {
      for (const user of users) {
        await connection.execute(
          `INSERT INTO users
            (id, business_id, email, password_hash, role, full_name, contact_number, auth_method, is_active, last_login_at, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              business_id = VALUES(business_id),
              email = VALUES(email),
              password_hash = VALUES(password_hash),
              role = VALUES(role),
              full_name = VALUES(full_name),
              contact_number = VALUES(contact_number),
              auth_method = VALUES(auth_method),
              is_active = VALUES(is_active),
              last_login_at = VALUES(last_login_at),
              updated_at = VALUES(updated_at)`,
          [
            user.id,
            resolvedBusinessId,
            user.email,
            user.password_hash,
            user.role,
            user.full_name,
            user.contact_number,
            user.auth_method,
            user.is_active ? 1 : 0,
            user.last_login_at,
            user.created_at,
            user.updated_at,
          ],
        );
        stats.users += 1;
      }
    }

    if (Array.isArray(customers)) {
      for (const customer of customers) {
        await connection.execute(
          `INSERT INTO customers
            (id, business_id, customer_code, full_name, phone_number, email, address, points_balance, lifetime_points, barcode_value, created_at, updated_at, is_active)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              customer_code = VALUES(customer_code),
              full_name = VALUES(full_name),
              phone_number = VALUES(phone_number),
              email = VALUES(email),
              address = VALUES(address),
              points_balance = VALUES(points_balance),
              lifetime_points = VALUES(lifetime_points),
              barcode_value = VALUES(barcode_value),
              updated_at = VALUES(updated_at),
              is_active = VALUES(is_active)`,
          [
            customer.id,
            resolvedBusinessId,
            customer.customer_code,
            customer.full_name,
            customer.phone_number,
            customer.email,
            customer.address,
            customer.points_balance,
            customer.lifetime_points,
            customer.barcode_value,
            customer.created_at,
            customer.updated_at,
            customer.is_active ? 1 : 0,
          ],
        );
        stats.customers += 1;
      }
    }

    if (Array.isArray(loyaltyLedger)) {
      for (const entry of loyaltyLedger) {
        await connection.execute(
          `INSERT INTO loyalty_ledger
            (id, business_id, customer_id, sale_id, entry_type, points, balance_after, notes, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              customer_id = VALUES(customer_id),
              sale_id = VALUES(sale_id),
              entry_type = VALUES(entry_type),
              points = VALUES(points),
              balance_after = VALUES(balance_after),
              notes = VALUES(notes)`,
          [
            entry.id,
            resolvedBusinessId,
            entry.customer_id,
            entry.sale_id,
            entry.entry_type,
            entry.points,
            entry.balance_after,
            entry.notes,
            entry.created_at,
          ],
        );
        stats.loyaltyLedger += 1;
      }
    }

    if (Array.isArray(cameras)) {
      for (const camera of cameras) {
        await connection.execute(
          `INSERT INTO cameras
            (id, business_id, name, location, stream_url, type, position, is_active, username, password, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              name = VALUES(name),
              location = VALUES(location),
              stream_url = VALUES(stream_url),
              type = VALUES(type),
              position = VALUES(position),
              is_active = VALUES(is_active),
              username = VALUES(username),
              password = VALUES(password)`,
          [
            camera.id,
            resolvedBusinessId,
            camera.name,
            camera.location,
            camera.stream_url,
            camera.type,
            camera.position,
            camera.is_active ? 1 : 0,
            camera.username,
            camera.password,
            camera.created_at,
          ],
        );
        stats.cameras += 1;
      }
    }

    if (Array.isArray(cctvTimestamps)) {
      for (const ts of cctvTimestamps) {
        await connection.execute(
          `INSERT INTO cctv_timestamps
            (id, business_id, camera_id, label, description, timestamp, notes, video_path, created_by, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              camera_id = VALUES(camera_id),
              label = VALUES(label),
              description = VALUES(description),
              timestamp = VALUES(timestamp),
              notes = VALUES(notes),
              video_path = VALUES(video_path),
              created_by = VALUES(created_by)`,
          [
            ts.id,
            resolvedBusinessId,
            ts.camera_id,
            ts.label,
            ts.description,
            ts.timestamp,
            ts.notes,
            ts.video_path,
            ts.created_by,
            ts.created_at,
          ],
        );
        stats.cctvTimestamps += 1;
      }
    }

    if (Array.isArray(attendanceEntries)) {
      for (const entry of attendanceEntries) {
        await connection.execute(
          `INSERT INTO attendance_entries
            (id, business_id, user_id, time, type, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              user_id = VALUES(user_id),
              time = VALUES(time),
              type = VALUES(type)`,
          [
            entry.id,
            resolvedBusinessId,
            entry.user_id,
            entry.time,
            entry.type,
            entry.created_at,
          ],
        );
        stats.attendanceEntries += 1;
      }
    }

    if (Array.isArray(attendanceLeaves)) {
      for (const leave of attendanceLeaves) {
        await connection.execute(
          `INSERT INTO attendance_leaves
            (id, business_id, user_id, date_key, payload, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              user_id = VALUES(user_id),
              date_key = VALUES(date_key),
              payload = VALUES(payload),
              updated_at = VALUES(updated_at)`,
          [
            leave.id,
            resolvedBusinessId,
            leave.user_id,
            leave.date_key,
            leave.payload,
            leave.created_at,
            leave.updated_at,
          ],
        );
        stats.attendanceLeaves += 1;
      }
    }

    if (Array.isArray(attendanceArchive)) {
      await connection.execute(
        'DELETE FROM attendance_archive WHERE business_id = ?',
        [resolvedBusinessId],
      );

      for (const archiveRow of attendanceArchive) {
        await connection.execute(
          `INSERT INTO attendance_archive
            (id, business_id, user_id, date_key, entries, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              entries = VALUES(entries),
              updated_at = VALUES(updated_at)`,
          [
            archiveRow.id,
            resolvedBusinessId,
            archiveRow.user_id,
            archiveRow.date_key,
            archiveRow.entries,
            archiveRow.created_at,
            archiveRow.updated_at,
          ],
        );
        stats.attendanceArchive += 1;
      }
    }

    if (attendanceSchedule && typeof attendanceSchedule === 'object') {
      const scheduleRows = Array.isArray(attendanceSchedule)
        ? attendanceSchedule
        : [attendanceSchedule];
      for (const schedule of scheduleRows) {
        await connection.execute(
          `INSERT INTO attendance_schedule
            (business_id, \`key\`, value, updated_at)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              value = VALUES(value),
              updated_at = VALUES(updated_at)`,
          [
            resolvedBusinessId,
            schedule.key ?? 'global',
            typeof schedule.value === 'string' ? schedule.value : JSON.stringify(schedule.value),
            schedule.updated_at,
          ],
        );
        stats.attendanceSchedule += 1;
      }
    }

    if (Array.isArray(activityLogs)) {
      for (const log of activityLogs) {
        await connection.execute(
          `INSERT INTO activity_logs
            (id, business_id, type, message, meta, created_at, sent)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              type = VALUES(type),
              message = VALUES(message),
              meta = VALUES(meta),
              sent = VALUES(sent)`,
          [
            log.id,
            resolvedBusinessId,
            log.type,
            log.message,
            log.meta,
            log.created_at,
            log.sent ? 1 : 0,
          ],
        );
        stats.activityLogs += 1;
      }
    }

    if (Array.isArray(products)) {
      for (const product of products) {
        await connection.execute(
          `INSERT INTO products
            (id, business_id, barcode, name, description, buying_price, category, selling_price, quantity, image_path, low_stock_threshold, shoe_sizes, size_type, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              barcode = VALUES(barcode),
              name = VALUES(name),
              description = VALUES(description),
              buying_price = VALUES(buying_price),
              category = VALUES(category),
              selling_price = VALUES(selling_price),
              quantity = VALUES(quantity),
              image_path = VALUES(image_path),
              low_stock_threshold = VALUES(low_stock_threshold),
              shoe_sizes = VALUES(shoe_sizes),
              size_type = VALUES(size_type),
              updated_at = VALUES(updated_at)`,
          [
            product.id,
            resolvedBusinessId,
            product.barcode,
            product.name,
            product.description,
            product.buying_price,
            product.category,
            product.selling_price,
            product.quantity,
            product.image_path,
            product.low_stock_threshold,
            product.shoe_sizes,
            product.size_type,
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
        // Accept both numeric/string id or sale_number from clients
        const saleId = sale.id || sale.sale_number || sale.saleNumber || null;
        await connection.execute(
          `INSERT INTO sales
            (id, business_id, cashier_id, cashier_name, customer_name, customer_id, payment_method, status, subtotal, discount, total_amount, amount_paid, change_amount, item_count, datetime, notes, reference_code, image_path, cancelled_reason, cancelled_by, cancelled_at, transaction_type, reservation_fee, courier, delivery_status, loyalty_points_earned, loyalty_points_redeemed, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
              notes = VALUES(notes),
              reference_code = VALUES(reference_code),
              image_path = VALUES(image_path),
              cancelled_reason = VALUES(cancelled_reason),
              cancelled_by = VALUES(cancelled_by),
              cancelled_at = VALUES(cancelled_at),
              transaction_type = VALUES(transaction_type),
              reservation_fee = VALUES(reservation_fee),
              courier = VALUES(courier),
              delivery_status = VALUES(delivery_status),
              loyalty_points_earned = VALUES(loyalty_points_earned),
              loyalty_points_redeemed = VALUES(loyalty_points_redeemed),
              updated_at = VALUES(updated_at)`,
          [
            saleId,
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
            sale.reference_code ?? sale.referenceCode ?? null,
            sale.image_path ?? sale.imagePath ?? null,
            sale.cancelled_reason ?? sale.cancelledReason ?? null,
            sale.cancelled_by ?? sale.cancelledBy ?? null,
            sale.cancelled_at ?? sale.cancelledAt ?? null,
            sale.transaction_type ?? sale.transactionType ?? 'pos',
            sale.reservation_fee ?? sale.reservationFee ?? null,
            sale.courier ?? sale.courier ?? null,
            sale.delivery_status ?? sale.deliveryStatus ?? null,
            sale.loyalty_points_earned ?? sale.loyaltyPointsEarned ?? 0,
            sale.loyalty_points_redeemed ?? sale.loyaltyPointsRedeemed ?? 0,
            sale.updated_at ?? sale.updatedAt ?? sale.created_at,
          ],
        );
        stats.sales += 1;
      }
    }

    if (Array.isArray(saleItems)) {
      for (const item of saleItems) {
        // Accept sale reference as sale_id or sale_number
        const refSaleId = item.sale_id || item.saleId || item.sale_number || item.saleNumber || null;
        await connection.execute(
          `INSERT INTO sale_items
            (sale_id, business_id, product_id, product_name, quantity, unit_price, discount, subtotal, shoe_size, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              product_name = VALUES(product_name),
              quantity = VALUES(quantity),
              unit_price = VALUES(unit_price),
              discount = VALUES(discount),
              subtotal = VALUES(subtotal),
              shoe_size = VALUES(shoe_size)`,
          [
            refSaleId,
            resolvedBusinessId,
            item.product_id,
            item.product_name,
            item.quantity,
            item.unit_price,
            item.discount,
            item.subtotal,
            item.shoe_size,
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

    if (Array.isArray(purchaseOrderItems)) {
      for (const item of purchaseOrderItems) {
        const refOrderId = item.purchase_order_id || item.order_id || item.orderId || null;
        await connection.execute(
          `INSERT INTO purchase_order_items
            (id, business_id, order_id, product_id, product_name, quantity, unit_price, total_price, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
              product_id = VALUES(product_id),
              product_name = VALUES(product_name),
              quantity = VALUES(quantity),
              unit_price = VALUES(unit_price),
              total_price = VALUES(total_price)`,
          [
            item.id,
            resolvedBusinessId,
            refOrderId,
            item.product_id,
            item.product_name,
            item.quantity,
            item.unit_price,
            item.total_price,
            item.created_at || new Date().toISOString(),
          ],
        );
        stats.purchaseOrderItems += 1;
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
  const authenticated = await resolveAuthenticatedBusiness(req);
  if (!authenticated.businessId) {
    return res.status(authenticated.status).json({ success: false, message: authenticated.message });
  }
  const businessId = authenticated.businessId;
  const submittedBusinessId = req.query.businessId || req.query.business_id || req.headers['x-business-id'];
  if (submittedBusinessId && String(submittedBusinessId) !== String(businessId)) {
    return res.status(403).json({ success: false, message: 'Sync business does not match the signed-in owner.' });
  }
  try {
    const [
      users,
      customers,
      loyaltyLedger,
      cameras,
      cctvTimestamps,
      attendanceEntries,
      attendanceLeaves,
      attendanceSchedule,
      attendanceArchive,
      activityLogs,
      products,
      suppliers,
      sales,
      saleItems,
      purchaseOrders,
      purchaseOrderItems,
      inventoryMovements,
      damageReports,
    ] = await Promise.all([
      query('SELECT * FROM users WHERE business_id = ?', [businessId]),
      query('SELECT * FROM customers WHERE business_id = ?', [businessId]),
      query('SELECT * FROM loyalty_ledger WHERE business_id = ?', [businessId]),
      query('SELECT * FROM cameras WHERE business_id = ?', [businessId]),
      query('SELECT * FROM cctv_timestamps WHERE business_id = ?', [businessId]),
      query('SELECT * FROM attendance_entries WHERE business_id = ?', [businessId]),
      query('SELECT * FROM attendance_leaves WHERE business_id = ?', [businessId]),
      query('SELECT * FROM attendance_schedule WHERE business_id = ?', [businessId]),
      query('SELECT * FROM attendance_archive WHERE business_id = ?', [businessId]),
      query('SELECT * FROM activity_logs WHERE business_id = ?', [businessId]),
      query('SELECT * FROM products WHERE business_id = ?', [businessId]),
      query('SELECT * FROM suppliers WHERE business_id = ?', [businessId]),
      query('SELECT * FROM sales WHERE business_id = ?', [businessId]),
      query('SELECT * FROM sale_items WHERE business_id = ?', [businessId]),
      query('SELECT * FROM purchase_orders WHERE business_id = ?', [businessId]),
      query('SELECT * FROM purchase_order_items WHERE business_id = ?', [
        businessId,
      ]),
      query('SELECT * FROM inventory_movements WHERE business_id = ?', [businessId]),
      query('SELECT * FROM damage_reports WHERE business_id = ?', [businessId]),
    ]);

    return res.json({
      success: true,
      users,
      customers,
      loyaltyLedger,
      cameras,
      cctvTimestamps,
      attendanceEntries,
      attendanceLeaves,
      attendanceSchedule,
      attendanceArchive,
      activityLogs,
      products,
      suppliers,
      sales,
      saleItems,
      purchaseOrders,
      purchaseOrderItems,
      inventoryMovements,
      damageReports,
    });
  } catch (error) {
    console.error('Sync /pull error:', error);
    return res.status(500).json({ success: false, message: 'Failed to pull sync payload from backend.' });
  }
});

module.exports = router;

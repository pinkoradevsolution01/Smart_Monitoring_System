// Verify only records belonging to the authenticated business. Query is
// injected so the completion rules can be tested without production data.
async function checkApprovedReorder(query, businessId, actionId, productId) {
  if (!Number.isInteger(productId) || productId <= 0) {
    return { ok: false, message: 'The reorder proposal no longer has a valid product.' };
  }
  const [order] = await query(
    `SELECT po.order_number, po.status FROM purchase_orders po
       WHERE po.business_id = ? AND INSTR(COALESCE(po.notes, ''), ?) > 0
         AND po.status IN ('approved', 'completed', 'partial', 'received')
         AND EXISTS (SELECT 1 FROM purchase_order_items pi
                      WHERE pi.business_id = po.business_id AND pi.order_id = po.id
                        AND pi.product_id = ?)
       LIMIT 1`,
    [businessId, `[SmartPlus action:${actionId}]`, productId],
  );
  if (!order) return { ok: false, message: 'Approve the linked purchase order and wait for it to sync before completing this reorder task.' };
  return { ok: true, message: `Purchase order ${order.order_number} was approved. Delivery receiving and restock are a separate task.` };
}

async function checkReceivedDelivery(query, businessId, orderNumber) {
  if (typeof orderNumber !== 'string' || !orderNumber.trim() || orderNumber.length > 255) {
    return { ok: false, message: 'The receiving task has no valid purchase order.' };
  }
  const [order] = await query(
    `SELECT po.order_number FROM purchase_orders po
       WHERE po.business_id = ? AND po.order_number = ? AND po.status = 'received'
         AND EXISTS (SELECT 1 FROM purchase_order_items pi WHERE pi.business_id = po.business_id AND pi.order_id = po.id)
         AND NOT EXISTS (
           SELECT 1 FROM purchase_order_items pi
            WHERE pi.business_id = po.business_id AND pi.order_id = po.id
              AND (pi.received_quantity < pi.quantity OR
                   COALESCE((SELECT SUM(rr.quantity) FROM restock_records rr
                     WHERE rr.business_id = po.business_id AND rr.product_id = pi.product_id
                       AND rr.referenced_by = CONCAT('Purchase Order ', po.order_number)), 0) <
                   (SELECT SUM(pi2.received_quantity) FROM purchase_order_items pi2
                     WHERE pi2.business_id = po.business_id AND pi2.order_id = po.id
                       AND pi2.product_id = pi.product_id))
         ) LIMIT 1`,
    [businessId, orderNumber],
  );
  if (!order) return { ok: false, message: 'The linked order must be fully received and its restock records synced before completing this task.' };
  return { ok: true, message: `Delivery and restock were verified for purchase order ${order.order_number}.` };
}

module.exports = { checkApprovedReorder, checkReceivedDelivery };

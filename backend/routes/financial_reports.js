const express = require('express');
const { query } = require('../db');
const {
  requireActiveBusiness,
  requireManagementRole,
  requireFinancialReporting,
} = require('../security/business_access');

const router = express.Router();
const MAX_RANGE_DAYS = 366;
const DEFAULT_VAT_RATE = 12;

function validDate(value) {
  return /^\d{4}-\d{2}-\d{2}$/.test(String(value || ''));
}

function setRange(req, res, next) {
  const today = new Date().toISOString().slice(0, 10);
  const from = String(req.query.from || today);
  const to = String(req.query.to || from);
  if (!validDate(from) || !validDate(to)) {
    return res.status(400).json({ success: false, message: 'from and to must be ISO dates (YYYY-MM-DD).' });
  }
  const span = (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86400000;
  if (span < 0 || span > MAX_RANGE_DAYS) {
    return res.status(400).json({ success: false, message: `Date range must be between 0 and ${MAX_RANGE_DAYS} days.` });
  }
  const rawRate = Number(req.query.vatRate ?? DEFAULT_VAT_RATE);
  if (!Number.isFinite(rawRate) || rawRate < 0 || rawRate > 100) {
    return res.status(400).json({ success: false, message: 'vatRate must be a number from 0 to 100.' });
  }
  req.financialRange = {
    from,
    to,
    toExclusive: new Date(Date.parse(`${to}T00:00:00Z`) + 86400000).toISOString().slice(0, 10),
    vatRate: rawRate,
  };
  return next();
}

function number(value) {
  return Number(value || 0);
}

function escapeCsv(value) {
  const text = String(value ?? '');
  const safe = /^[=+\-@]/.test(text) ? `'${text}` : text;
  return `"${safe.replace(/"/g, '""')}"`;
}

async function buildReport(req) {
  const { businessId } = req.businessContext;
  const { from, to, toExclusive, vatRate } = req.financialRange;
  const salesParams = [businessId, from, toExclusive];
  const [sales] = await query(
    `SELECT
       COALESCE(SUM(subtotal), 0) AS gross_sales,
       COALESCE(SUM(discount), 0) AS discounts,
       COALESCE(SUM(total_amount), 0) AS net_sales,
       COUNT(*) AS completed_transactions
     FROM sales
     WHERE business_id = ? AND status = 'completed' AND datetime >= ? AND datetime < ?`,
    salesParams,
  );
  const [cancelled] = await query(
    `SELECT COUNT(*) AS cancelled_transactions,
            COALESCE(SUM(total_amount), 0) AS cancelled_amount
       FROM sales
      WHERE business_id = ? AND status = 'cancelled' AND datetime >= ? AND datetime < ?`,
    salesParams,
  );
  const paymentMethods = await query(
    `SELECT payment_method, COUNT(*) AS transactions, COALESCE(SUM(total_amount), 0) AS total
       FROM sales
      WHERE business_id = ? AND status = 'completed' AND datetime >= ? AND datetime < ?
      GROUP BY payment_method ORDER BY total DESC`,
    salesParams,
  );
  const [expenseTotals] = await query(
    `SELECT COALESCE(SUM(amount), 0) AS operating_expenses,
            COALESCE(SUM(tax_amount), 0) AS input_tax
       FROM expenses
      WHERE business_id = ? AND expense_date >= ? AND expense_date < ?`,
    salesParams,
  );
  const expensesByCategory = await query(
    `SELECT category, COALESCE(SUM(amount), 0) AS total
       FROM expenses
      WHERE business_id = ? AND expense_date >= ? AND expense_date < ?
      GROUP BY category ORDER BY total DESC`,
    salesParams,
  );
  const [costOfGoods] = await query(
    `SELECT COALESCE(SUM(si.quantity * COALESCE(p.buying_price, 0)), 0) AS estimated_cogs
       FROM sale_items si
       INNER JOIN sales s ON s.id = si.sale_id AND s.business_id = si.business_id
       LEFT JOIN products p ON p.id = si.product_id AND p.business_id = si.business_id
      WHERE s.business_id = ? AND s.status = 'completed' AND s.datetime >= ? AND s.datetime < ?`,
    salesParams,
  );
  const transactions = await query(
    `SELECT id, datetime, reference_code, cashier_name, customer_name, payment_method,
            subtotal, discount, total_amount
       FROM sales
      WHERE business_id = ? AND status = 'completed' AND datetime >= ? AND datetime < ?
      ORDER BY datetime ASC, id ASC LIMIT 1000`,
    salesParams,
  );

  const netSales = number(sales.net_sales);
  const rateDecimal = vatRate / 100;
  // Sales totals are treated as VAT-inclusive only for this operational
  // summary. Businesses must verify tax treatment before filing.
  const taxableSales = rateDecimal === 0 ? netSales : netSales / (1 + rateDecimal);
  const outputVat = netSales - taxableSales;
  const operatingExpenses = number(expenseTotals.operating_expenses);
  const estimatedCogs = number(costOfGoods.estimated_cogs);

  return {
    notice: 'Review-ready operational summary only. Validate against your BIR-registered invoicing/POS records and tax adviser before filing or submission.',
    range: { from, to, timezone: 'Asia/Manila' },
    zReading: {
      generatedAt: new Date().toISOString(),
      completedTransactions: Number(sales.completed_transactions || 0),
      cancelledTransactions: Number(cancelled.cancelled_transactions || 0),
      grossSales: number(sales.gross_sales),
      discounts: number(sales.discounts),
      netSales,
      cancelledAmount: number(cancelled.cancelled_amount),
      paymentMethods,
    },
    eSales: transactions,
    vatSummary: {
      ratePercent: vatRate,
      vatInclusiveSales: netSales,
      estimatedTaxableSales: taxableSales,
      estimatedOutputVat: outputVat,
      recordedInputVat: number(expenseTotals.input_tax),
      estimatedVatPayable: Math.max(0, outputVat - number(expenseTotals.input_tax)),
    },
    profitAnalysis: {
      netSales,
      estimatedCostOfGoods: estimatedCogs,
      operatingExpenses,
      estimatedProfit: netSales - estimatedCogs - operatingExpenses,
      expensesByCategory,
    },
  };
}

router.use(requireActiveBusiness, requireManagementRole, requireFinancialReporting, setRange);

router.get('/summary', async (req, res) => {
  try {
    const report = await buildReport(req);
    return res.json({ success: true, data: report });
  } catch (error) {
    console.error('Financial report error:', error);
    return res.status(500).json({ success: false, message: 'Failed to generate the financial report.' });
  }
});

router.get('/export', async (req, res) => {
  try {
    const report = await buildReport(req);
    const rows = [
      ['BIR-ready operational report', `${report.range.from} to ${report.range.to}`],
      ['Notice', report.notice],
      [],
      ['Z-reading summary'],
      ['Completed transactions', report.zReading.completedTransactions],
      ['Cancelled transactions', report.zReading.cancelledTransactions],
      ['Gross sales', report.zReading.grossSales],
      ['Discounts', report.zReading.discounts],
      ['Net sales', report.zReading.netSales],
      ['Operating expenses', report.profitAnalysis.operatingExpenses],
      ['Estimated cost of goods', report.profitAnalysis.estimatedCostOfGoods],
      ['Estimated profit', report.profitAnalysis.estimatedProfit],
      [],
      ['VAT summary'],
      ['VAT rate (%)', report.vatSummary.ratePercent],
      ['VAT-inclusive sales', report.vatSummary.vatInclusiveSales],
      ['Estimated taxable sales', report.vatSummary.estimatedTaxableSales],
      ['Estimated output VAT', report.vatSummary.estimatedOutputVat],
      ['Recorded input VAT', report.vatSummary.recordedInputVat],
      ['Estimated VAT payable', report.vatSummary.estimatedVatPayable],
      [],
      ['eSales detail'],
      ['Transaction ID', 'Date/time', 'Reference', 'Cashier', 'Customer', 'Payment', 'Subtotal', 'Discount', 'Total'],
      ...report.eSales.map((sale) => [sale.id, sale.datetime, sale.reference_code, sale.cashier_name, sale.customer_name, sale.payment_method, sale.subtotal, sale.discount, sale.total_amount]),
    ];
    const body = rows.map((row) => row.map(escapeCsv).join(',')).join('\n');
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="bir-ready-${report.range.from}-to-${report.range.to}.csv"`);
    return res.send(body);
  } catch (error) {
    console.error('Financial report export error:', error);
    return res.status(500).json({ success: false, message: 'Failed to export the financial report.' });
  }
});

module.exports = router;

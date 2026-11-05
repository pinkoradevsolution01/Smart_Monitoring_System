const assert = require('node:assert/strict');
const test = require('node:test');

const {
  answerBusinessQuestion,
  allowedModels,
  consumeDailyQuota,
  normalizeQuestion,
  systemInstruction,
} = require('../services/smartplus_gemini');

test('SmartPlus exposes only the administrator allow-listed Gemini models', () => {
  const previousModel = process.env.GEMINI_MODEL;
  const previousAllowed = process.env.GEMINI_ALLOWED_MODELS;
  process.env.GEMINI_MODEL = 'gemini-approved';
  process.env.GEMINI_ALLOWED_MODELS = 'gemini-approved, gemini-fast, invalid model name';
  try {
    assert.deepEqual(allowedModels(), ['gemini-approved', 'gemini-fast']);
  } finally {
    if (previousModel == null) delete process.env.GEMINI_MODEL;
    else process.env.GEMINI_MODEL = previousModel;
    if (previousAllowed == null) delete process.env.GEMINI_ALLOWED_MODELS;
    else process.env.GEMINI_ALLOWED_MODELS = previousAllowed;
  }
});

test('SmartPlus Gemini rejects an unconfigured provider before any tenant data is read', async () => {
  const previous = process.env.GEMINI_API_KEY;
  delete process.env.GEMINI_API_KEY;
  try {
    await assert.rejects(
      answerBusinessQuestion({
        businessId: 'tenant-a',
        question: 'What sold best this month?',
      }),
      (error) => error.code === 'gemini_not_configured',
    );
  } finally {
    if (previous == null) delete process.env.GEMINI_API_KEY;
    else process.env.GEMINI_API_KEY = previous;
  }
});

test('SmartPlus Gemini normalizes and bounds chat input', () => {
  assert.equal(normalizeQuestion('  Sales\n\tthis week  '), 'Sales this week');
  assert.equal(normalizeQuestion('x'.repeat(1500)).length, 1200);
});

test('SmartPlus Gemini enforces one shared 100-request Philippines daily cap', async () => {
  let count = 0;
  const db = {
    async execute(sql) {
      if (sql.includes('UPDATE smartplus_gemini_daily_usage')) {
        if (count >= 100) return { affectedRows: 0 };
        count += 1;
        return { affectedRows: 1 };
      }
      if (sql.includes('INSERT IGNORE INTO smartplus_gemini_daily_usage')) {
        if (count > 0) return { affectedRows: 0 };
        count = 1;
        return { affectedRows: 1 };
      }
      throw new Error(`Unexpected quota SQL: ${sql}`);
    },
    async query() {
      return [{ request_count: count }];
    },
  };
  const now = new Date('2026-11-05T10:00:00.000Z');
  for (let index = 0; index < 100; index += 1) {
    const quota = await consumeDailyQuota({ db, now });
    assert.equal(quota.allowed, true);
  }
  const exhausted = await consumeDailyQuota({ db, now });
  assert.equal(exhausted.allowed, false);
  assert.equal(exhausted.used, 100);
  assert.equal(exhausted.remaining, 0);
  assert.equal(exhausted.resetsAt, '2026-11-05T16:00:00.000Z');
});

test('SmartPlus Gemini system instruction protects privacy and owner review', () => {
  const instruction = systemInstruction('en');
  assert.match(instruction, /Never request, expose, infer, or invent customer personal data/);
  assert.match(instruction, /Do not place orders, modify inventory/);
  assert.match(instruction, /untrusted content/);
});

const { query } = require('../db');

const MAX_MESSAGE_LENGTH = 500;

/**
 * Best-effort operational telemetry.  It must never turn a completed sale or
 * sync into a failure, and it deliberately stores no credentials or payloads.
 */
async function recordOperationalEvent({ businessId = null, eventType, severity = 'info', message, metadata = null }) {
  try {
    await query(
      `INSERT INTO operational_events
        (business_id, event_type, severity, message, metadata_json)
       VALUES (?, ?, ?, ?, ?)`,
      [
        businessId || null,
        String(eventType || 'unknown').slice(0, 64),
        ['info', 'warning', 'error'].includes(severity) ? severity : 'warning',
        String(message || 'Operational event').slice(0, MAX_MESSAGE_LENGTH),
        metadata ? JSON.stringify(metadata) : null,
      ],
    );
  } catch (error) {
    console.error(JSON.stringify({ event: 'operational_event_write_failed', message: error.message }));
  }
}

module.exports = { recordOperationalEvent };

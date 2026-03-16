/**
 * Status Handler — POST /api/status
 *
 * Called by the Flutter mobile app (or any client) to report a citizen's safety status.
 * Emits a 'citizen-status' WebSocket event to all connected dashboard clients.
 *
 * Body: { sos_id: number, status: 'safe' | 'unsafe' | 'evacuating' }
 * Response: { received: true, sos_id, status }
 */
const express = require('express');
const router = express.Router();

const VALID_STATUSES = ['safe', 'unsafe', 'evacuating'];

router.post('/', async (req, res) => {
    const { sos_id, status } = req.body;

    // ── Validation ──────────────────────────────────────────────
    if (!sos_id || typeof sos_id !== 'number') {
        return res.status(400).json({
            error: true,
            code: 'VALIDATION_FAILED',
            message: 'sos_id must be a number.'
        });
    }

    if (!status || !VALID_STATUSES.includes(status)) {
        return res.status(400).json({
            error: true,
            code: 'VALIDATION_FAILED',
            message: `status must be one of: ${VALID_STATUSES.join(', ')}`
        });
    }

    // ── Emit WebSocket event to all dashboard clients ────────────
    try {
        const { getIO } = require('../../ws/socket');
        getIO().emit('citizen-status', { sos_id, status, reported_at: new Date().toISOString() });
        console.log(`[STATUS] citizen-status emitted: sos_id=${sos_id} status=${status}`);
    } catch (wsErr) {
        // Non-fatal — log but don't fail the response
        console.error('[STATUS] WebSocket emit failed (non-fatal):', wsErr.message);
    }

    return res.status(200).json({ received: true, sos_id, status });
});

module.exports = router;

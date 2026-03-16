const { Server } = require('socket.io');

let ioInstance;

/**
 * Four events this backend emits:
 *  - io.emit('new-sos', payload)        -> fired from sos.js handler
 *  - io.emit('triage-complete', payload) -> fired from sos.js triage handler
 *  - io.emit('broadcast-alert', payload) -> fired from alert.js handler
 *  - io.emit('citizen-status', payload)  -> fired from status.js handler
 * 
 * Note: Do NOT accept any events from clients. This is a broadcast-only server.
 */

function initSocket(httpServer) {
    ioInstance = new Server(httpServer, {
        cors: {
            origin: '*',
            methods: ['GET', 'POST']
        }
    });

    ioInstance.on('connection', (socket) => {
        console.log(`Dashboard client connected: ${socket.id}`);

        socket.on('disconnect', () => {
            console.log(`Dashboard client disconnected: ${socket.id}`);
        });

        // No client event listeners are registered per playbook rules.
    });

    return ioInstance;
}

function getIO() {
    if (!ioInstance) {
        throw new Error('Socket.io has not been initialized yet.');
    }
    return ioInstance;
}

module.exports = { initSocket, getIO };

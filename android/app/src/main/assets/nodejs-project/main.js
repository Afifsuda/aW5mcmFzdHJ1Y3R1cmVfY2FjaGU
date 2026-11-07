const bridge = require('flutter-bridge');
const http = require('http');
const fs = require('fs');
const path = require('path');

console.log('[Node.js Mobile Engine] Booted inside APK process!');
bridge.send('_NODE_', 'STARTED');

let routerStarted = false;

bridge.on('start-9router', (bundlePath) => {
  console.log('[Node.js Mobile] Start signal with path:', bundlePath);
  if (routerStarted) {
    bridge.send('router-status', 'ALREADY_RUNNING');
    return;
  }

  try {
    const entryPoints = [
      path.join(bundlePath, 'node_modules', '9router', 'bin', '9router.js'),
      path.join(bundlePath, 'bin', '9router.js'),
      path.join(bundlePath, 'dist', 'index.js')
    ];

    let entry = null;
    for (const p of entryPoints) {
      if (fs.existsSync(p)) {
        entry = p;
        break;
      }
    }

    if (entry) {
      console.log('[Node.js Mobile] Launching 9router from entry:', entry);
      process.argv = ['node', entry, 'start', '--port', '20128'];
      require(entry);
      routerStarted = true;
      bridge.send('router-status', 'RUNNING');
    } else {
      console.error('[Node.js Mobile] Entry not found in:', bundlePath);
      bridge.send('router-status', 'NOT_FOUND');
    }
  } catch (err) {
    console.error('[Node.js Mobile] Execution error:', err);
    bridge.send('router-status', 'ERROR: ' + err.message);
  }
});

bridge.on('ping', () => {
  bridge.send('pong', 'ALIVE');
});

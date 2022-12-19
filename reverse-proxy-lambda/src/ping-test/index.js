const net = require('node:net');
const version = 1.2;

/**
 * @returns {Promise<string>}
 * @param host {string}
 * @param port {number}
 */
function ping(host, port) {
  return new Promise((resolve, reject) => {
    try {
      const socket = net.createConnection(
        { port: port || 80, host, timeout: 1000 },
        () => {
          socket.destroy();
          resolve(`Connected successfully to ${host}`);
        }
      );

      socket.on('error', (error) => {
        socket.destroy();
        resolve(
          `Failed to connect to host ${host}, error = ${JSON.stringify(error)}`
        );
      });

      socket.on('timeout', () => {
        console.debug(`DEBUG: got timeout for ${host}, ${port} `);
        socket.destroy();
        resolve(`Timed out connecting to host=${host}, port=${port}`);
      });
    } catch (err) {
      reject(err);
    }
  });
}

exports.handler = async (event) => {
  /**
   *
   * @type {{host: string; port: number}[]}
   */
  const testList = [
    { host: '10.0.1.1', port: 22 },
    { host: '10.0.1.1', port: 23 },
    { host: '10.0.1.86', port: 22 },
    { host: 'google.com', port: 80 },
    { host: 'yahoo.com', port: 80 },
  ];

  const messages = [];

  for (const entry of testList) {
    try {
      const response = await ping(entry.host, entry.port);
      messages.push(
        `For host=${entry.host}, port ${
          entry.port
        }, response = ${JSON.stringify(response)}`
      );
    } catch (e) {
      console.log('ERROR!!!');
      console.log(e);
    }
  }

  return {
    event,
    messages,
    version,
  };
};

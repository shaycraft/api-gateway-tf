const ping = require('ping');
const version = 1.2;

function probeIt(host) {
  return new Promise((res, err) => {
    try {
      ping.sys.probe(host, function (isAlive) {
        console.log('isAlive = ', isAlive);
        const msg = `For host=${host}, isAlive returned ${isAlive}`;
        console.log(msg);
        res(msg);
      });
    } catch (e) {
      err(e);
    }
  });
}

exports.handler = async (event) => {
  const hosts = ['10.0.1.1', '10.0.1.86', 'google.com', 'yahoo.com'];

  const messages = [];

  for (const host of hosts) {
    messages.push(await probeIt(host));
  }

  return {
    event,
    messages,
    version,
  };
};

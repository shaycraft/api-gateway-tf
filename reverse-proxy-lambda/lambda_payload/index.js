const ping = require('ping');

function probeIt(host) {
  return new Promise((res, err) => {
    try {
      ping.sys.probe(host, function (isAlive) {
        console.log('isAlive = ', isAlive);
        const msg = isAlive
          ? 'host ' + host + ' is alive'
          : 'host ' + host + ' is dead';
        console.log(msg);
        res(msg);
      });
    } catch (e) {
      err(e);
    }
  });
}

const mainThang = async (event) => {
  const hosts = ['10.0.1.1', '10.0.1.86', 'google.com', 'yahoo.com'];

  const messages = [];

  for (const host of hosts) {
    messages.push(await probeIt(host));
  }

  messages.push(JSON.stringify(event));

  return {
    statusCode: 200,
    body: JSON.stringify(messages),
  };
};

exports.handler = mainThang;

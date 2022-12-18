const ping = require('ping');
const version = 1.2;

function probeIt(host) {
  return ping.promise.probe(host);
}

exports.handler = async (event) => {
  const hosts = ['10.0.1.1', '10.0.1.86', 'google.com', 'yahoo.com'];

  const messages = [];

  for (const host of hosts) {
    try {
      const response = await probeIt(host);
      messages.push(`For host=${host}, response = ${JSON.stringify(response)}`);
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

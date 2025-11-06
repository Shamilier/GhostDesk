const formatArgs = (level, args) => {
  if (args.length === 0) {
    return [];
  }

  if (typeof args[0] === 'string') {
    const [first, ...rest] = args;
    return [`[portal] [${level}] ${first}`, ...rest];
  }

  return [`[portal] [${level}]`, ...args];
};

module.exports = {
  info: (...args) => {
    console.log(...formatArgs('info', args));
  },
  warn: (...args) => {
    console.warn(...formatArgs('warn', args));
  },
  error: (...args) => {
    console.error(...formatArgs('error', args));
  },
};

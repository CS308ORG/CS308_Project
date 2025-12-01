module.exports = {
  testEnvironment: 'node',
  coveragePathIgnorePatterns: ['/node_modules/'],
  testMatch: ['**/*.test.js'],
  collectCoverageFrom: [
    '*.js',
    '!jest.config.js',
    '!coverage/**'
  ],
  coverageReporters: ['text', 'lcov', 'html']
};


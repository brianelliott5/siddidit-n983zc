// Jest configuration for Hello World web application
// @jest/types version: ^29.0.0

import type { Config } from '@jest/types';

/**
 * Creates and exports Jest configuration for testing the Hello World application
 * Includes settings for:
 * - TypeScript support via ts-jest
 * - JSDOM test environment for HTML testing
 * - Coverage reporting and thresholds
 * - Module resolution and mocking
 * - Test timeouts and verbosity
 */
const config: Config.InitialOptions = {
  // Use ts-jest preset for TypeScript support
  preset: 'ts-jest',

  // Use jsdom environment for HTML/DOM testing
  testEnvironment: 'jsdom',

  // Test file locations
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.ts'],

  // File extensions to consider
  moduleFileExtensions: ['ts', 'js', 'json', 'node'],

  // TypeScript transformation
  transform: {
    '^.+\\.ts$': 'ts-jest'
  },

  // Test setup files
  setupFilesAfterEnv: [],

  // Coverage configuration
  coverageDirectory: 'coverage',
  collectCoverageFrom: [
    'src/**/*.{ts,js}',
    '!**/node_modules/**'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },

  // Test timeout (10 seconds)
  testTimeout: 10000,

  // Enable verbose output
  verbose: true,

  // Module name mapping for static assets
  moduleNameMapper: {
    '\\.(html|css)$': '<rootDir>/tests/mocks/fileMock.ts'
  },

  // Additional settings for HTML validation testing
  globals: {
    'ts-jest': {
      tsconfig: '<rootDir>/tsconfig.json'
    }
  },

  // Ignore patterns
  testPathIgnorePatterns: [
    '/node_modules/',
    '/dist/'
  ],

  // Reporter configuration
  reporters: [
    'default',
    [
      'jest-junit',
      {
        outputDirectory: 'coverage',
        outputName: 'junit.xml',
        classNameTemplate: '{classname}',
        titleTemplate: '{title}'
      }
    ]
  ],

  // Error handling
  bail: 1,
  maxWorkers: '50%'
};

export default config;
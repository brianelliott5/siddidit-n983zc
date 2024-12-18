// @jest/globals v29.0.0 - Jest testing framework
import { describe, test, expect, beforeAll } from '@jest/globals';

// Node.js built-in modules
import fs from 'fs';
import path from 'path';
import { promisify } from 'util';

// Internal validation script
import { validateHtml } from '../scripts/validate-html.sh';

// Convert callback-based fs functions to Promise-based
const readFile = promisify(fs.readFile);
const access = promisify(fs.access);

// Constants
const HTML_FILE_PATH = path.join(__dirname, '../src/index.html');
const VALIDATION_SCRIPT_PATH = path.join(__dirname, '../scripts/validate-html.sh');
const MAX_FILE_SIZE = 1024; // 1KB in bytes

// Test suite configuration
jest.setTimeout(10000); // 10 second timeout

describe('HTML Validation Tests', () => {
    let htmlContent: string;

    beforeAll(async () => {
        // Verify index.html exists and is readable
        try {
            await access(HTML_FILE_PATH, fs.constants.R_OK);
        } catch (error) {
            throw new Error(`index.html not found or not readable at ${HTML_FILE_PATH}`);
        }

        // Verify validation script exists and is executable
        try {
            await access(VALIDATION_SCRIPT_PATH, fs.constants.X_OK);
        } catch (error) {
            throw new Error(`validate-html.sh not found or not executable at ${VALIDATION_SCRIPT_PATH}`);
        }

        // Read HTML content
        htmlContent = await readFile(HTML_FILE_PATH, 'utf-8');
    });

    test('file size should be under 1KB', async () => {
        const stats = await fs.promises.stat(HTML_FILE_PATH);
        expect(stats.size).toBeLessThanOrEqual(MAX_FILE_SIZE);
    });

    test('should have valid HTML5 doctype declaration', () => {
        expect(htmlContent).toMatch(/^\s*<!DOCTYPE html>/i);
    });

    test('should have html element with lang attribute', () => {
        expect(htmlContent).toMatch(/<html\s+[^>]*lang="en"[^>]*>/i);
    });

    test('should have required meta tags', () => {
        // UTF-8 charset
        expect(htmlContent).toMatch(/<meta\s+[^>]*charset="UTF-8"[^>]*>/i);
        
        // Viewport
        expect(htmlContent).toMatch(
            /<meta\s+[^>]*name="viewport"[^>]*content="[^"]*width=device-width[^"]*"[^>]*>/i
        );
    });

    test('should have required security headers', () => {
        // Content Security Policy
        expect(htmlContent).toMatch(
            /<meta\s+[^>]*http-equiv="Content-Security-Policy"[^>]*content="[^"]*default-src 'self'[^"]*"[^>]*>/i
        );

        // X-Frame-Options
        expect(htmlContent).toMatch(
            /<meta\s+[^>]*http-equiv="X-Frame-Options"[^>]*content="DENY"[^>]*>/i
        );

        // X-Content-Type-Options
        expect(htmlContent).toMatch(
            /<meta\s+[^>]*http-equiv="X-Content-Type-Options"[^>]*content="nosniff"[^>]*>/i
        );

        // HSTS
        expect(htmlContent).toMatch(
            /<meta\s+[^>]*http-equiv="Strict-Transport-Security"[^>]*content="[^"]*max-age=31536000[^"]*"[^>]*>/i
        );
    });

    test('should have semantic HTML structure', () => {
        // Check for main element
        expect(htmlContent).toMatch(/<main\b[^>]*>/i);
        
        // Check for h1 heading
        expect(htmlContent).toMatch(/<h1\b[^>]*>/i);
        
        // Verify single h1 usage
        const h1Count = (htmlContent.match(/<h1\b[^>]*>/g) || []).length;
        expect(h1Count).toBe(1);
    });

    test('should pass W3C HTML5 validation', async () => {
        const validationResult = await validateHtml(HTML_FILE_PATH, {
            localOnly: true, // Use local validation for CI/CD
            debug: false,
            quiet: true
        });
        expect(validationResult.success).toBe(true);
        expect(validationResult.errors).toHaveLength(0);
    });

    test('should pass WCAG 2.1 Level A accessibility checks', async () => {
        const validationResult = await validateHtml(HTML_FILE_PATH, {
            localOnly: true,
            wcag: '2.1 A',
            debug: false,
            quiet: true
        });
        expect(validationResult.success).toBe(true);
        expect(validationResult.accessibility.violations).toHaveLength(0);
    });

    test('should have proper content structure', () => {
        // Title element
        expect(htmlContent).toMatch(/<title\b[^>]*>Hello World<\/title>/i);
        
        // Main content
        expect(htmlContent).toMatch(/<h1\b[^>]*>Hello World<\/h1>/i);
    });

    test('should have basic responsive design meta tag', () => {
        expect(htmlContent).toMatch(
            /<meta\s+[^>]*name="viewport"[^>]*content="[^"]*initial-scale=1\.0[^"]*"[^>]*>/i
        );
    });

    test('should have proper character encoding', () => {
        // Check UTF-8 declaration
        expect(htmlContent).toMatch(/<meta\s+[^>]*charset="UTF-8"[^>]*>/i);
        
        // Verify no BOM in file
        const hasBOM = htmlContent.charCodeAt(0) === 0xFEFF;
        expect(hasBOM).toBe(false);
    });
});
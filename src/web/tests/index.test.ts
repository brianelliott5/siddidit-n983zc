// Jest testing framework - v29.0.0
import { describe, test, expect, beforeEach } from '@jest/globals';
// JSDOM for DOM simulation - v22.0.0
import { JSDOM } from 'jsdom';
// Accessibility testing - v4.8.0
import axe from 'axe-core';
// HTML5 validation - v1.3.0
import { validateHTML } from 'w3c-validator';

// Import the HTML content from the source file
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Read the HTML file content
const htmlPath = resolve(__dirname, '../src/index.html');
const htmlContent = readFileSync(htmlPath, 'utf-8');

describe('Index Page Tests', () => {
    let dom: JSDOM;
    let document: Document;
    let window: Window;

    beforeEach(() => {
        // Set up a fresh JSDOM instance for each test
        dom = new JSDOM(htmlContent, {
            url: 'http://localhost',
            resources: 'usable',
            runScripts: 'dangerously'
        });
        document = dom.window.document;
        window = dom.window;
    });

    test('HTML Structure Validation', async () => {
        // Verify DOCTYPE declaration
        expect(htmlContent.trim().startsWith('<!DOCTYPE html>')).toBe(true);

        // Check HTML lang attribute
        const htmlTag = document.querySelector('html');
        expect(htmlTag?.getAttribute('lang')).toBe('en');

        // Validate meta tags
        const metaTags = document.querySelectorAll('meta');
        const metaAttributes = Array.from(metaTags).map(tag => ({
            charset: tag.getAttribute('charset'),
            name: tag.getAttribute('name'),
            content: tag.getAttribute('content')
        }));

        // Check charset meta tag
        expect(metaAttributes.some(meta => meta.charset === 'UTF-8')).toBe(true);

        // Check viewport meta tag
        expect(metaAttributes.some(meta => 
            meta.name === 'viewport' && 
            meta.content === 'width=device-width, initial-scale=1.0'
        )).toBe(true);

        // Validate title element
        expect(document.title).toBe('Hello World');

        // Validate semantic structure
        expect(document.querySelector('main')).not.toBeNull();
        expect(document.querySelector('h1')).not.toBeNull();
    });

    test('Content Validation', () => {
        // Verify Hello World text content
        const h1Element = document.querySelector('h1');
        expect(h1Element?.textContent).toBe('Hello World');

        // Check text visibility
        const style = window.getComputedStyle(h1Element!);
        expect(style.display).not.toBe('none');
        expect(style.visibility).not.toBe('hidden');

        // Verify content is within main element
        const mainElement = document.querySelector('main');
        expect(mainElement?.contains(h1Element)).toBe(true);
    });

    test('Accessibility Compliance', async () => {
        // Run axe accessibility tests
        const results = await axe.run(document);
        expect(results.violations).toHaveLength(0);

        // Check semantic structure
        expect(document.querySelector('main')).not.toBeNull();
        expect(document.querySelector('h1')).not.toBeNull();

        // Verify heading hierarchy
        const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
        expect(headings[0].tagName).toBe('H1');

        // Check for lang attribute
        expect(document.documentElement.hasAttribute('lang')).toBe(true);
    });

    test('Performance Metrics', async () => {
        // Measure HTML size
        const htmlSize = Buffer.from(htmlContent).length;
        expect(htmlSize).toBeLessThan(10 * 1024); // Should be under 10KB

        // Check for render-blocking resources
        const blockingScripts = document.querySelectorAll('script:not([async]):not([defer])');
        expect(blockingScripts).toHaveLength(0);

        // Verify style implementation
        const styleElement = document.querySelector('style');
        expect(styleElement).not.toBeNull();
        
        // Check for critical CSS properties
        const bodyStyles = window.getComputedStyle(document.body);
        expect(bodyStyles.display).toBe('flex');
        expect(bodyStyles.justifyContent).toBe('center');
        expect(bodyStyles.alignItems).toBe('center');
    });

    test('Security Headers Validation', () => {
        // Check security meta tags
        const securityHeaders = {
            'Content-Security-Policy': "default-src 'self'",
            'X-Frame-Options': 'DENY',
            'X-Content-Type-Options': 'nosniff',
            'Strict-Transport-Security': 'max-age=31536000',
            'Referrer-Policy': 'no-referrer'
        };

        Object.entries(securityHeaders).forEach(([header, value]) => {
            const metaTag = document.querySelector(`meta[http-equiv="${header}"]`);
            expect(metaTag).not.toBeNull();
            expect(metaTag?.getAttribute('content')).toBe(value);
        });
    });

    test('W3C HTML5 Validation', async () => {
        // Validate HTML against W3C standards
        const validationResult = await validateHTML(htmlContent);
        expect(validationResult.isValid).toBe(true);
        expect(validationResult.errors).toHaveLength(0);
    });

    test('Browser Compatibility Checks', () => {
        // Check for standard HTML5 elements
        const modernElements = ['main', 'header', 'footer', 'nav', 'article', 'section'];
        modernElements.forEach(element => {
            expect(document.createElement(element).constructor).not.toBe(HTMLUnknownElement);
        });

        // Verify viewport meta for mobile compatibility
        const viewportMeta = document.querySelector('meta[name="viewport"]');
        expect(viewportMeta?.getAttribute('content')).toBe('width=device-width, initial-scale=1.0');

        // Check for standard CSS properties
        const styles = document.querySelector('style')?.textContent;
        expect(styles).toContain('display: flex');
        expect(styles).toContain('justify-content: center');
        expect(styles).toContain('align-items: center');
    });
});
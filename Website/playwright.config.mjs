import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './Tests/Browser',
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  workers: process.env.CI ? 2 : undefined,
  timeout: 30_000,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: 'http://127.0.0.1:4173',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure'
  },
  projects: ['chromium', 'webkit'].flatMap(browserName => [
    { name: `${browserName}-desktop`, use: { browserName, viewport: { width: 1280, height: 900 } } },
    { name: `${browserName}-narrow`, use: { browserName, viewport: { width: 320, height: 800 } } }
  ]),
  webServer: {
    command: 'python3 -m http.server 4173 --bind 127.0.0.1 --directory BuildPublic',
    url: 'http://127.0.0.1:4173',
    reuseExistingServer: false
  }
});

const { chromium } = require('playwright');

// Parse CLI arguments from process.argv
function parseArgs(argv) {
  const args = argv.slice(2);
  const result = {
    url: null,
    output: null,
    fullPage: false,
    selector: null,
    width: 1440,
    height: 900,
    wait: 2000,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--url') {
      result.url = args[++i];
    } else if (arg === '--output') {
      result.output = args[++i];
    } else if (arg === '--full-page') {
      result.fullPage = true;
    } else if (arg === '--selector') {
      result.selector = args[++i];
    } else if (arg === '--width') {
      result.width = parseInt(args[++i], 10);
    } else if (arg === '--height') {
      result.height = parseInt(args[++i], 10);
    } else if (arg === '--wait') {
      result.wait = parseInt(args[++i], 10);
    }
  }

  return result;
}

async function main() {
  const args = parseArgs(process.argv);

  if (!args.url) {
    process.stderr.write('Error: --url is required\n');
    process.exit(1);
  }
  if (!args.output) {
    process.stderr.write('Error: --output is required\n');
    process.exit(1);
  }

  let browser;
  try {
    // 1. Launch chromium headless
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();

    // 2. Set viewport size
    await page.setViewportSize({ width: args.width, height: args.height });

    // 3. Navigate to URL, wait for networkidle
    await page.goto(args.url, { waitUntil: 'networkidle' });

    // 4. Wait additional ms for dynamic rendering
    await page.waitForTimeout(args.wait);

    // 5-7. Capture screenshot based on options
    if (args.selector) {
      const element = await page.$(args.selector);
      if (!element) {
        process.stderr.write(`Warning: selector "${args.selector}" not found, falling back to viewport screenshot\n`);
        await page.screenshot({ path: args.output, fullPage: false });
      } else {
        // 5. Screenshot specific element
        await element.screenshot({ path: args.output });
      }
    } else if (args.fullPage) {
      // 6. Screenshot full scrollable page
      await page.screenshot({ path: args.output, fullPage: true });
    } else {
      // 7. Screenshot viewport
      await page.screenshot({ path: args.output, fullPage: false });
    }

    // 9. Print output path to stdout
    process.stdout.write(args.output + '\n');

    // Exit with code 0 on success
    process.exit(0);
  } catch (err) {
    process.stderr.write(`Error: ${err.message}\n`);
    process.exit(1);
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

main();

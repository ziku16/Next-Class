import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const styles = readFileSync(new URL('../src/styles/index.css', import.meta.url), 'utf8');

test('hero has no unstable yellow circle and keeps its Today sticker below the screenshot', () => {
  assert.doesNotMatch(styles, /\.hero::before\s*\{/);

  const captionRules = [...styles.matchAll(/\.hero-screen-preview figcaption\s*\{([^}]*)\}/g)];
  const bottomOffsets = captionRules
    .map(([, declarations]) => declarations.match(/bottom:\s*([^;]+);/)?.[1].trim())
    .filter(Boolean);
  assert.deepEqual(bottomOffsets, ['-43px']);
});

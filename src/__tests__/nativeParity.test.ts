import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/**
 * Adding a prop means changing the codegen spec and the native side together,
 * and nothing else checks that both happened — the `SYNC:` comments are only a
 * reminder. A prop that exists in the spec but is never read natively type-checks,
 * builds, and silently does nothing.
 *
 * This is deliberately a text search rather than a parse: it is looking for
 * evidence that someone wired the name up, not for a particular expression.
 */
const root = join(__dirname, '..', '..');

const read = (path: string) => readFileSync(join(root, path), 'utf8');

const spec = read('src/RNImeTextInputNativeComponent.ts');

/**
 * Comments are stripped before searching. The native side explains itself in
 * prose, and a prop named only in a comment — including one saying it is *not*
 * supported — would otherwise satisfy the search and pass vacuously.
 */
function withoutComments(source: string): string {
  return source.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
}

const native = ['ios/RNImeTextInput.mm', 'ios/RNImeTextInputAttributes.mm', 'ios/RNImeTextInputAttributes.h']
  .map((path) => withoutComments(read(path)))
  .join('\n');

/** The property names declared in an interface body, ignoring comments. */
function declaredProps(source: string, interfaceName: string): string[] {
  const start = source.indexOf(`interface ${interfaceName}`);
  if (start === -1) {
    throw new Error(`${interfaceName} not found in the spec`);
  }

  const body = source.slice(source.indexOf('{', start));
  const end = body.indexOf('\n}');
  const withoutComments = body
    .slice(0, end)
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/\/\/.*$/gm, '');

  return [...withoutComments.matchAll(/^\s{2}(\w+)\??:/gm)].map((match) => match[1]);
}

describe('the codegen spec and the native implementation stay in step', () => {
  it('finds the props to check', () => {
    // A guard on the guard: a rename that breaks the extraction would otherwise
    // turn every assertion below into a vacuous pass.
    expect(declaredProps(spec, 'NativeProps').length).toBeGreaterThan(30);
  });

  it.each(declaredProps(spec, 'NativeProps'))('`%s` is read by the native side', (prop) => {
    expect(native).toContain(prop);
  });

  it.each(['focus', 'blur', 'clear', 'setSelection'])(
    'the `%s` command has a native implementation',
    (command) => {
      expect(native).toMatch(new RegExp(`^- \\(void\\)${command}\\b`, 'm'));
    }
  );

  it('declares every command the spec exposes', () => {
    const supported = spec.match(/supportedCommands:\s*\[([^\]]+)\]/);
    expect(supported).not.toBeNull();

    const names = [...(supported?.[1] ?? '').matchAll(/'(\w+)'/g)].map((match) => match[1]);
    expect(names.sort()).toEqual(['blur', 'clear', 'focus', 'setSelection']);
  });
});

// RN 번역 리소스(futureETP apps/mobile/src/i18n/locales/{ko,en}.ts)에서 App/Resources/Localizable.xcstrings를 만든다 (D-033).
// 키는 RN과 같은 점 경로(`accessKey.guide`), 값의 자리 표시자 `{{name}}`은 그대로 둔다(Swift가 이름으로 바꾼다).
// 실행: node scripts/gen-strings.mjs            파일을 다시 쓴다
//       node scripts/gen-strings.mjs --check    파일이 최신인지, Swift가 쓰는 키가 모두 있는지 본다(check.sh)
// futureETP 위치는 FUTUREETP_DIR, 기본 ../futureETP_ReactNative
import { readdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const futureETP = path.resolve(root, process.env.FUTUREETP_DIR ?? '../futureETP_ReactNative');
const output = path.join(root, 'App/Resources/Localizable.xcstrings');
const locale = async (lang) => {
  const file = path.join(futureETP, 'apps/mobile/src/i18n/locales', `${lang}.ts`);
  return (await import(pathToFileURL(file).href))[lang];
};

const flatten = (object, prefix = '', out = {}) => {
  for (const [key, value] of Object.entries(object)) {
    const name = prefix ? `${prefix}.${key}` : key;
    if (typeof value === 'string') out[name] = value;
    else flatten(value, name, out);
  }
  return out;
};

const ko = flatten(await locale('ko'));
const en = flatten(await locale('en'));
const missing = Object.keys(ko).filter((key) => !(key in en));
if (missing.length > 0) throw new Error(`en에 없는 키: ${missing.join(', ')}`);

const unit = (value) => ({ stringUnit: { state: 'translated', value } });
const strings = {};
for (const key of Object.keys(ko).sort()) {
  strings[key] = {
    extractionState: 'manual',
    localizations: { en: unit(en[key]), ko: unit(ko[key]) },
  };
}
// Xcode가 저장하는 모양(`" : "`, 2칸 들여쓰기)에 맞춰 Xcode에서 열어도 diff가 생기지 않게 한다
const text =
  JSON.stringify({ sourceLanguage: 'ko', strings, version: '1.0' }, null, 2).replace(
    /^(\s*"(?:[^"\\]|\\.)*"):/gm,
    '$1 :',
  ) + '\n';

// Swift 소스의 문구 키: Text("a.b")·Button("a.b")처럼 따옴표 안의 점 경로 중 최상위 이름이 RN 리소스에 있는 것
const swiftKeys = async () => {
  const tops = new Set(Object.keys(ko).map((key) => key.split('.')[0]));
  const keys = new Set();
  for (const dir of ['App', 'Core/Sources', 'Features']) {
    for (const entry of await readdir(path.join(root, dir), { recursive: true })) {
      if (!entry.endsWith('.swift') || entry.includes('/Tests/')) continue;
      const source = await readFile(path.join(root, dir, entry), 'utf8');
      for (const [, key] of source.matchAll(/"([a-z][A-Za-z]*(?:\.[A-Za-z0-9_]+)+)"/g)) {
        if (tops.has(key.split('.')[0])) keys.add(key);
      }
    }
  }
  return keys;
};

if (process.argv.includes('--check')) {
  const current = await readFile(output, 'utf8').catch(() => '');
  if (current !== text) {
    console.error('Localizable.xcstrings가 RN 리소스와 다르다: node scripts/gen-strings.mjs');
    process.exit(1);
  }
  const unknown = [...(await swiftKeys())].filter((key) => !(key in ko));
  if (unknown.length > 0) {
    console.error(`RN 리소스에 없는 문구 키: ${unknown.join(', ')}`);
    process.exit(1);
  }
  console.log(`${Object.keys(ko).length}개 키 최신`);
} else {
  await writeFile(output, text);
  console.log(`${Object.keys(ko).length}개 키 → ${path.relative(root, output)}`);
}

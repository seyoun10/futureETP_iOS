// 계약 테스트의 스키마 쪽: Core/Tests/Fixtures/<스키마>[.<변형>].json(성공 봉투)과
// Core/Tests/Fixtures/Requests/<스키마>[.<변형>].json(요청 본문·query 객체)이 원본 zod 스키마를 통과하는지 (D-142, IOS-007).
// JSON Schema 파일은 이 zod 스키마에서 생성되므로 zod로 보면 refine 규칙까지 함께 본다.
// 실행: node scripts/validate-fixtures.mjs (futureETP 위치는 FUTUREETP_DIR, 기본 ../futureETP)
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const futureETP = path.resolve(root, process.env.FUTUREETP_DIR ?? '../futureETP');
const shared = (file) => import(pathToFileURL(path.join(futureETP, 'packages/shared/src', file)).href);

// 계약 스키마 이름 → [원본 파일, export 이름] (futureETP packages/shared/src/contract.ts의 SCHEMAS)
const SOURCES = {
  health: ['health.ts', 'healthSchema'],
  commodities: ['commodities.ts', 'commoditiesSchema'],
  disparityChart: ['disparity.ts', 'disparityChartSchema'],
  curve: ['curve.ts', 'curveSchema'],
  contractsChart: ['contracts.ts', 'contractsChartSchema'],
  etpList: ['etps.ts', 'etpListSchema'],
  etpDetail: ['etps.ts', 'etpDetailSchema'],
  calendar: ['calendar.ts', 'calendarSchema'],
  settings: ['settings.ts', 'settingsSchema'],
  device: ['devices.ts', 'deviceSchema'],
};

// 요청 본문·query. 앱이 보내는 값이 서버 변환(정렬·반올림) 없이 그대로 남는지도 본다
const REQUEST_SOURCES = {
  settingsPatch: ['settings.ts', 'settingsPatchSchema'],
  deviceRegistration: ['devices.ts', 'deviceRegistrationSchema'],
  disparityQuery: ['queries.ts', 'disparityQuerySchema'],
  contractsQuery: ['queries.ts', 'contractsQuerySchema'],
  curveQuery: ['queries.ts', 'curveQuerySchema'],
  calendarQuery: ['queries.ts', 'calendarQuerySchema'],
};

const { envelopeSchema } = await shared('envelope.ts');
let failed = 0;
async function validate(dir, sources, check) {
  const files = (await readdir(dir)).filter((f) => f.endsWith('.json')).sort();
  if (files.length === 0) {
    console.error(`${dir}: 예시 파일이 없다`);
    failed++;
  }
  for (const file of files) {
    const name = file.split('.')[0];
    const source = sources[name];
    if (!source) {
      console.error(`${file}: 모르는 스키마 이름 ${name}`);
      failed++;
      continue;
    }
    const schema = (await shared(source[0]))[source[1]];
    const body = JSON.parse(await readFile(path.join(dir, file), 'utf8'));
    const problem = check(schema, body);
    if (problem) {
      console.error(`${file}: ${problem}`);
      failed++;
    } else {
      console.log(`${file}: ok`);
    }
  }
}

const fixtures = path.join(root, 'Core/Tests/Fixtures');
await validate(fixtures, SOURCES, (schema, body) => {
  const result = envelopeSchema(schema).safeParse(body);
  if (!result.success) return result.error.message;
  return body.success === true ? null : '실패 봉투';
});
await validate(path.join(fixtures, 'Requests'), REQUEST_SOURCES, (schema, body) => {
  const result = schema.safeParse(body);
  if (!result.success) return result.error.message;
  // query는 서버가 숫자·배열로 바꾸므로 본문만 비교한다
  if (!('levels' in body) && !('ma' in body) && JSON.stringify(result.data) !== JSON.stringify(body)) {
    return `서버가 값을 바꾼다: ${JSON.stringify(result.data)}`;
  }
  return null;
});
process.exit(failed === 0 ? 0 : 1);

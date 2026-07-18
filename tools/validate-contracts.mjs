// Validates every fixture in packages/contracts/fixtures against the event
// envelope, per-event payload schemas, and the module's level-config schema.
// CI fails if any fixture drifts from the contracts. Exit 0 = all valid.
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import Ajv from "ajv/dist/2020.js";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const contracts = join(root, "packages", "contracts");

const readJson = (p) => JSON.parse(readFileSync(p, "utf8"));

const envelope = readJson(join(contracts, "events", "v1", "envelope.json"));
const payloads = readJson(join(contracts, "events", "v1", "payloads.json"));

const ajv = new Ajv({ allErrors: true, strict: true });
const validateEnvelope = ajv.compile(envelope);
const payloadValidators = Object.fromEntries(
  Object.entries(payloads.$defs).map(([name, schema]) => [name, ajv.compile(schema)])
);

const levelSchemas = {};
for (const f of readdirSync(join(contracts, "levels", "v1"))) {
  const moduleKey = f.replace(".config.json", "");
  levelSchemas[moduleKey] = ajv.compile(readJson(join(contracts, "levels", "v1", f)));
}

let failures = 0;
const fail = (msg, errors) => {
  failures++;
  console.error(`FAIL: ${msg}`);
  if (errors) console.error(JSON.stringify(errors, null, 2));
};

const fixtureDir = join(contracts, "fixtures");
for (const f of readdirSync(fixtureDir).filter((f) => f.endsWith(".json"))) {
  const fixture = readJson(join(fixtureDir, f));

  const levelValidator = levelSchemas[fixture.module_key];
  if (!levelValidator) {
    fail(`${f}: no level-config schema for module '${fixture.module_key}'`);
    continue;
  }
  if (!levelValidator(fixture.level_config)) {
    fail(`${f}: level_config invalid`, levelValidator.errors);
  }

  let prevSeq = 0;
  for (const event of fixture.events) {
    if (!validateEnvelope(event)) {
      fail(`${f}: event seq=${event.seq} envelope invalid`, validateEnvelope.errors);
      continue;
    }
    if (event.seq <= prevSeq) {
      fail(`${f}: seq not strictly increasing at seq=${event.seq}`);
    }
    prevSeq = event.seq;

    const payloadValidator = payloadValidators[event.event_type];
    if (!payloadValidator(event.payload)) {
      fail(`${f}: payload invalid for ${event.event_type} (seq=${event.seq})`, payloadValidator.errors);
    }
  }
  if (fixture.events.length === 0) fail(`${f}: fixture has no events`);
  console.log(`ok: ${f} (${fixture.events.length} events)`);
}

if (failures > 0) {
  console.error(`${failures} contract violation(s).`);
  process.exit(1);
}
console.log("All fixtures conform to contracts.");

import {readFileSync} from 'node:fs';
import {simplify} from '../_build/js/release/build/validation/bridge/bridge.js';
for (const line of readFileSync(0,'utf8').trim().split('\n')) console.log(simplify(line));

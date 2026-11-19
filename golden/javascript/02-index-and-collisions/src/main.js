import { hello } from "./a/index.js";
import { fmt as fmtB } from "./b/util.js";
import * as autil from "./a/util.js";

hello();
fmtB("x");
autil.fmt("y");

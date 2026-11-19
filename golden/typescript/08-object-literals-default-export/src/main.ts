import api, { handlers, make } from "./api";

api.start();
handlers.ping();
make().run();

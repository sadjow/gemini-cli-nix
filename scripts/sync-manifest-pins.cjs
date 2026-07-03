// Upstream tags sometimes pin exact versions in package.json manifests that
// diverge from package-lock.json (e.g. v0.49.0 pins tar@7.5.8 while the
// lockfile resolves tar@7.5.11). npm cannot reconcile that in Nix's offline
// build, so rewrite mismatched exact pins to the locked versions.
const fs = require("fs");

const lock = JSON.parse(fs.readFileSync("package-lock.json", "utf8"));
const packages = lock.packages || {};

const lockedVersion = (workspacePath, name) => {
  let parts = workspacePath ? workspacePath.split("/") : [];
  for (;;) {
    const entry = packages[[...parts, "node_modules", name].join("/")];
    if (entry && !entry.link) return entry.version || null;
    if (parts.length === 0) return null;
    parts.pop();
  }
};

const EXACT_PIN = /^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$/;
const SECTIONS = ["dependencies", "devDependencies", "optionalDependencies"];
const manifestDirs = Object.keys(packages).filter(
  (p) => !p.includes("node_modules"),
);

for (const dir of manifestDirs) {
  const file = dir ? dir + "/package.json" : "package.json";
  if (!fs.existsSync(file)) continue;

  const manifest = JSON.parse(fs.readFileSync(file, "utf8"));
  let changed = false;

  for (const section of SECTIONS) {
    for (const [name, spec] of Object.entries(manifest[section] || {})) {
      if (!EXACT_PIN.test(spec)) continue;
      const locked = lockedVersion(dir, name);
      if (locked && locked !== spec) {
        manifest[section][name] = locked;
        changed = true;
        console.log("sync " + file + ": " + name + " " + spec + " -> " + locked);
      }
    }
  }

  if (changed) {
    fs.writeFileSync(file, JSON.stringify(manifest, null, 2) + "\n");
  }
}

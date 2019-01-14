workflow "New workflow" {
  on = "push"
  resolves = ["If master", "Run Benchmark"]
}

action "Build & Test" {
  uses = "actions/docker/cli@76ff57a"
  args = "build -t stestagg/cavro ."
}

action "If master" {
  uses = "actions/bin/filter@b2bea0749eed6beb495a8fa194c071847af60ea1"
  needs = ["Build & Test"]
  args = "branch master"
}

action "Run Benchmark" {
  uses = "actions/docker/cli@c08a5fc9e0286844156fefff2c141072048141f6"
  needs = ["If master"]
  secrets = ["GITHUB_TOKEN"]
  args = "run --rm stestagg/cavro -c 'make benchmark'"
}

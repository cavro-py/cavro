workflow "Build&Test" {
  on = "push"
  resolves = [
    "Upload updated results",
  ]
}

action "Build & Test" {
  uses = "actions/docker/cli@76ff57a"
  args = "build -t stestagg/cavro ."
  needs = ["Only run on master"]
}

action "Only run on master" {
  uses = "actions/bin/filter@b2bea0749eed6beb495a8fa194c071847af60ea1"
  args = "branch master"
}

action "Run Benchmark" {
  uses = "actions/docker/cli@c08a5fc9e0286844156fefff2c141072048141f6"
  needs = ["Build & Test"]
  secrets = ["GITHUB_TOKEN"]
  args = "run -e GITHUB_TOKEN --rm stestagg/cavro -c 'make benchmark'"
}

action "Upload updated results" {
  uses = "actions/docker/cli@c08a5fc9e0286844156fefff2c141072048141f6"
  needs = ["Run Benchmark"]
  args = "run -e GITHUB_TOKEN --rm stestagg/cavro -c 'make upload_benchmark_docker'"
  secrets = ["GITHUB_TOKEN"]
}

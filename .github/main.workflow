workflow "Build&Test" {
  on = "push"
  resolves = [
    "Upload updated results",
  ]
}

action "Build & Test" {
  uses = "actions/docker/cli@master"
  args = "build -t stestagg/cavro ."
  needs = ["Only run on master"]
}

action "Only run on master" {
  uses = "actions/bin/filter@master"
  args = "branch master"
}

action "Run Benchmark" {
  uses = "actions/docker/cli@master"
  needs = ["Build & Test"]
  secrets = ["GITHUB_TOKEN"]
  args = "run -e GITHUB_TOKEN --rm stestagg/cavro -c 'make benchmark'"
}

action "Upload updated results" {
  uses = "actions/docker/cli@master"
  needs = ["Run Benchmark"]
  args = "run -e GITHUB_TOKEN --rm stestagg/cavro -c 'make upload_benchmark_docker'"
  secrets = ["GITHUB_TOKEN"]
}

# Concourse DGOSS-in-Docker

Optimized for use with [Concourse CI](http://concourse.ci/).

The image is Alpine based, and includes Dgoss, Docker, Docker Compose, and Docker Squash, as well as Bash.

Image published to Docker Hub: [tomreeb/concourse-dgossind](https://hub.docker.com/r/tomreeb/concourse-dgossind/).

Forked from [karlkfi/concourse-dcind](https://github.com/karlkfi/concourse-dcind)
Inspired by [meAmidos/dcind](https://github.com/meAmidos/dcind),  [concourse/docker-image-resource](https://github.com/concourse/docker-image-resource/blob/master/assets/common.sh), and [mesosphere/mesos-slave-dind](https://github.com/mesosphere/mesos-slave-dind).

## Features

Unlike meAmidos/dcind, this image...

- Does not require the user to manually start docker.
- Uses errexit, pipefail, and nounset.
- Configures timeout (`DOCKERD_TIMEOUT`) on dockerd start to account for mis-configuration (docker log will be output).
- Accepts arbitrary dockerd arguments via optional `DOCKER_OPTS` environment variable.
- Passes through `--garden-mtu` from the parent Gardian container if `--mtu` is not specified in `DOCKER_OPTS`.
- Sets `--data-root /scratch/docker` to bypass the graph filesystem if `--data-root` is not specified in `DOCKER_OPTS`.

## Build

```
docker build -t tomreeb/concourse-dgossind .
```

## Example

Here is an example of a Concourse [job](http://concourse.ci/concepts.html) that uses ```tomreeb/concourse-dgossind``` image to run a dgoss test on a freshly built container.

```yaml
jobs:
- name: dgoss-test
  plan:
  - get: code
    params:
      depth: 1
    passed:
    - unit-tests
    trigger: true
  - task: dgoss-tests
    privileged: true
    config:
      platform: linux
      image_resource:
        type: docker-image
        source:
          repository: tomreeb/concourse-dgossind
      inputs:
      - name: code
      run:
        path: entrypoint.sh
        args:
        - bash
        - -ceux
        - |
          # Build container from Dockerfile
          docker build -t test-image:test -f Dockerfile .
          # Run DGoss against newly built container
          bash dgoss run test-image:test
```

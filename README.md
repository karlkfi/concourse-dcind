# Concourse Docker-Compose-in-Docker

Optimized for use with [Concourse CI](http://concourse.ci/).

The image is Alpine based, and includes Docker, Docker Compose, and Docker Squash, as well as Bash.

Image published to Docker Hub: [karlkfi/concourse-dcind](https://hub.docker.com/r/karlkfi/concourse-dcind/).

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
docker build -t karlkfi/concourse-dcind .
```

## Example

Here is an example of a Concourse [job](http://concourse.ci/concepts.html) that uses ```karlkfi/concourse-dcind``` image to run a bunch of containers in a task, and then runs the integration test suite. You can find a full version of this example in the [```example```](example) directory.

```yaml
jobs:
- name: integration
  plan:
  - get: code
    params:
      depth: 1
    passed:
    - unit-tests
    trigger: true
  - task: integration-tests
    privileged: true
    config:
      platform: linux
      image_resource:
        type: docker-image
        source:
          repository: karlkfi/concourse-dcind
      inputs:
      - name: code
      run:
        path: bash
        args:
        - -ceux
        - |
          # start containers
          docker-compose -f code/example/integration.yml run tests
          # stop and remove containers
          docker-compose -f code/example/integration.yml down
          # remove volumes
          docker volume rm $(docker volume ls -q)
```

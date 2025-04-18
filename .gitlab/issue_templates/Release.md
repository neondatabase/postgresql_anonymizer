
* [ ] Check that **all** CI jobs run without errors on the `latest` branch
* [ ] Close all remaining issues on the current milestone
* [ ] Update the [Changelog]
* [ ] Update the [AUTHORS.md] list
* [ ] Write the announcement in [NEWS.md]
* [ ] Rebuild the docker image `latest` and upload it
      (`make docker_image docker_push`)
* [ ] Close the current milestone and open the next one
* [ ] Rebase the `stable` branch from `latest`
* [ ] Rebuild the docker image `stable` and upload it
      (`DOCKER_TAG=stable make docker_image docker_push`)
* [ ] Tag the `latest` branch
* [ ] Build the docker image `x.y.z` and upload it
      (`DOCKER_TAG=x.y.z make docker_image docker_push`)
* [ ] Create a branch `x.y.z` based on `stable`
* [ ] Launch [a new pipeline] on the `x.y.z` branch
* [ ] Once the pipeline is done, trigger the deploy task to publish the packages
* [ ] Update the upstream repositories
* [ ] On the [Tags page], click on `Create a Release`
* [ ] Bump to the new version number in [Cargo.toml]
* [ ] Publish the announcement

[Changelog]: CHANGELOG.md
[NEWS.md]: NEWS.md
[Cargo.toml]: Cargo.toml
[Tags page]: https://gitlab.com/dalibo/postgresql_anonymizer/-/tags/
[a new pipeline]: https://gitlab.com/dalibo/postgresql_anonymizer/-/pipelines/new

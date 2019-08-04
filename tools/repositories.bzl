# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("//tools:bazel_hash_dict.bzl", "BAZEL_HASH_DICT")
load(":common.bzl", "BAZEL_VERSIONS")

_BAZEL_BINARY_PACKAGES = [
  "http://releases.bazel.build/{version}/release/bazel-{version}{installer}-{platform}.{extension}",
  "https://github.com/bazelbuild/bazel/releases/download/{version}/bazel-{version}{installer}-{platform}.{extension}",
]

def _get_platform_name(rctx):
  os_name = rctx.os.name.lower()

  if os_name.startswith("mac os"):
    return "darwin-x86_64"
  if os_name.startswith("windows"):
    return "windows-x86_64"

  # We default on linux-x86_64 because we only support 3 platforms
  return "linux-x86_64"

def _is_windows(rctx):
  return _get_platform_name(rctx).startswith("windows")

def _get_installer(rctx):
  platform = _get_platform_name(rctx)
  version = rctx.attr.version

  if _is_windows(rctx):
    extension = "zip"
    installer = ""
  else:
    extension = "sh"
    installer = "-installer"

  urls = [url.format(version=version, installer=installer, platform=platform, extension=extension) for url in _BAZEL_BINARY_PACKAGES]
  args = {"url": urls, "type": "zip"}
  if version in BAZEL_HASH_DICT and platform in BAZEL_HASH_DICT[version]:
    args["sha256"] = BAZEL_HASH_DICT[version][platform]
  rctx.download_and_extract(**args)

def _bazel_repository_impl(rctx):
  _get_installer(rctx)
  rctx.file("WORKSPACE", "workspace(name='%s')" % rctx.attr.name)
  rctx.file("BUILD", """
filegroup(
  name = "bazel_binary",
  srcs = select({
    "@bazel_tools//src/conditions:windows" : ["bazel.exe"],
    "//conditions:default": ["bazel-real","bazel"],
  }),
  visibility = ["//visibility:public"])""")

bazel_binary = repository_rule(
    attrs = {
        "version": attr.string(default = "0.5.3"),
    },
    implementation = _bazel_repository_impl,
)

"""Download a bazel binary for integration test.

Args:
  version: the version of Bazel to download.

Limitation: only support Linux and macOS for now.
"""

def bazel_binaries(versions = BAZEL_VERSIONS):
  """Download all bazel binaries specified in BAZEL_VERSIONS."""
  for version in versions:
    name = "build_bazel_bazel_" + version.replace(".", "_")
    if not native.existing_rule(name):
      bazel_binary(name = name, version = version)

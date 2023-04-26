load("//elm:toolchain.bzl", "ElmToolchainInfo")

def get_compiler(ctx: "context", toolchain: ElmToolchainInfo.type, elm_json: "artifact") -> "artifact":
    """
    Produce a script that `cd`s to the correct directory, then runs `elm`.
    """
    return ctx.actions.write(
        "elm.sh",
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            cmd_args(
                elm_json,
                format = "cd $(dirname {})"
            ),
            cmd_args(
                toolchain.elm,
                format = "exec {} $@"
            ).relative_to(elm_json, parent = 1)
        ],
        is_executable = True,
        with_inputs = True,
    )

def _elm_docs_impl(ctx: "context") -> [DefaultInfo.type]:
    docs = ctx.actions.declare_output(ctx.attrs.out)
    compiler = get_compiler(ctx, ctx.attrs._elm_toolchain[ElmToolchainInfo], ctx.attrs.elm_json)

    cmd = cmd_args([compiler, "make", "--docs", docs.as_output()])
    cmd.hidden(ctx.attrs.elm_json, ctx.attrs.srcs)

    ctx.actions.run(cmd, category = "elm")

    return [DefaultInfo(default_output = docs)]

elm_docs = rule(
    impl = _elm_docs_impl,
    attrs = {
        "out": attrs.string(default="docs.json"),
        "elm_json": attrs.source(),
        "srcs": attrs.list(attrs.source()),
        "_elm_toolchain": attrs.toolchain_dep(default="toolchains//:elm"),
    }
)

def _elm_app_impl(ctx: "context") -> [DefaultInfo.type]:
    out = ctx.actions.declare_output(ctx.attrs.out)
    compiler = get_compiler(ctx, ctx.attrs._elm_toolchain[ElmToolchainInfo], ctx.attrs.elm_json)

    cmd = cmd_args([
        compiler,
        "make",
        cmd_args(ctx.attrs.main).relative_to(ctx.attrs.elm_json, parent = 1),
        "--output",
        cmd_args(out.as_output()).relative_to(ctx.attrs.elm_json, parent = 1),
    ])
    cmd.hidden(ctx.attrs.elm_json, ctx.attrs.srcs)

    if ctx.attrs.debug and ctx.attrs.optimize:
        fail("Only one of `optimize` and `debug` may be true!")

    if ctx.attrs.debug:
        cmd.add("--debug")

    if ctx.attrs.optimize:
        cmd.add("--optimize")

    ctx.actions.run(cmd, category = "elm")

    return [DefaultInfo(default_output = out)]

elm_app = rule(
    impl = _elm_app_impl,
    attrs = {
        "out": attrs.string(default = "app.js"),
        "elm_json": attrs.source(),
        "main": attrs.source(),
        "srcs": attrs.list(attrs.source()),
        "debug": attrs.bool(default = False),
        "optimize": attrs.bool(default = False),
        "_elm_toolchain": attrs.toolchain_dep(default="toolchains//:elm"),
    }
)

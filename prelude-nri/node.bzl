load("//node:toolchain.bzl", "NodeToolchainInfo")
load("@prelude//python:toolchain.bzl", "PythonToolchainInfo")

def _node_modules_impl(ctx: "context") -> [DefaultInfo.type]:
    out = ctx.actions.declare_output("node_modules")

    node_toolchain = ctx.attrs._node_toolchain[NodeToolchainInfo]

    ctx.actions.run(
        [
            ctx.attrs._python_toolchain[PythonToolchainInfo].interpreter,
            node_toolchain.build_node_modules[DefaultInfo].default_outputs,
            out.as_output(),
            "--package", ctx.attrs.package,
            "--package-lock", ctx.attrs.package_lock,
            "--bin-dir", node_toolchain.bin_dir[DefaultInfo].default_outputs,
        ],
        category = "npm",
    )

    return [DefaultInfo(default_output = out)]

node_modules = rule(
    impl = _node_modules_impl,
    attrs = {
        "package": attrs.source(),
        "package_lock": attrs.source(),
        "_node_toolchain": attrs.toolchain_dep(
            default="toolchains//:node",
            providers=[NodeToolchainInfo]
        ),
        "_python_toolchain": attrs.toolchain_dep(
            default="toolchains//:python",
            providers=[PythonToolchainInfo]
        ),
    }
)

def _npm_bin_impl(ctx: "context") -> [[DefaultInfo.type, RunInfo.type]]:
    bin_name = ctx.attrs.bin_name or ctx.attrs.name

    out = ctx.actions.declare_output(bin_name)

    node_toolchain = ctx.attrs._node_toolchain[NodeToolchainInfo]

    ctx.actions.run(
        [
            ctx.attrs._python_toolchain[PythonToolchainInfo].interpreter,
            node_toolchain.build_npm_bin[DefaultInfo].default_outputs,
            ctx.attrs.node_modules,
            bin_name,
            out.as_output(),
            "--bin-dir", node_toolchain.bin_dir[DefaultInfo].default_outputs,
        ],
        category = "build_npm_bin",
    )

    return [
        DefaultInfo(default_output = out),
        RunInfo(out),
    ]

npm_bin = rule(
    impl = _npm_bin_impl,
    attrs = {
        "bin_name": attrs.option(attrs.string(), default=None),
        "node_modules": attrs.source(),
        "_node_toolchain": attrs.toolchain_dep(
            default="toolchains//:node",
            providers=[NodeToolchainInfo]
        ),
        "_python_toolchain": attrs.toolchain_dep(
            default="toolchains//:python",
            providers=[PythonToolchainInfo]
        ),
    }
)

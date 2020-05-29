load("@build_bazel_rules_nodejs//:providers.bzl", "DeclarationInfo", "JSEcmaScriptModuleInfo", "JSNamedModuleInfo", "node_modules_aspect", "run_node")
load("@build_bazel_rules_nodejs//internal/linker:link_node_modules.bzl", "module_mappings_aspect")
load(":esm5.bzl", "es5_aspect", "esm5_root_dir", "flatten_esm5")
load("//tools:defaults.bzl", "copy_file", "join", "convert_kebab_case_to_camel_case")



# Convert from a package name on npm to an identifier that's a legal global symbol
#  @angular/core -> ng.core
#  @angular/platform-browser-dynamic/testing -> ng.platformBrowserDynamic.testing
def _global_name(package_name):
    # strip npm scoped package qualifier
    start = 1 if package_name.startswith("@") else 0
    parts = package_name[start:].split("/")
    result_parts = []
    for p in parts:
        # Special case for angular's short name
        if p == "angular":
            result_parts.append("ng")
        else:
            result_parts.append(convert_kebab_case_to_camel_case(p))
    return ".".join(result_parts)

WELL_KNOWN_GLOBALS = {p: _global_name(p) for p in [
    "@angular/upgrade",
    "@angular/upgrade/static",
    "@angular/forms",
    "@angular/core/testing",
    "@angular/core",
    "@angular/platform-server/testing",
    "@angular/platform-server",
    "@angular/platform-webworker-dynamic",
    "@angular/platform-webworker",
    "@angular/common/testing",
    "@angular/common",
    "@angular/common/http/testing",
    "@angular/common/http",
    "@angular/elements",
    "@angular/platform-browser-dynamic/testing",
    "@angular/platform-browser-dynamic",
    "@angular/compiler/testing",
    "@angular/compiler",
    "@angular/animations",
    "@angular/animations/browser/testing",
    "@angular/animations/browser",
    "@angular/service-worker/config",
    "@angular/service-worker",
    "@angular/platform-browser/testing",
    "@angular/platform-browser",
    "@angular/platform-browser/animations",
    "@angular/router/upgrade",
    "@angular/router/testing",
    "@angular/router",
    "rxjs",
    "rxjs/operators",
]}

def _filter_js(files):
    "Filter the files out where the extension is .js or .mjs"
    return [f for f in files if f.extension == "js" or f.extension == "mjs"]

def _get_bundle_name(input):
    input_file = input.files.to_list()[0]

    if len(input_file.extension) > 0:
        return input_file.basename.replace("." + input_file.extension, "")

    return input_file.basename

def _ng_sub_package_impl(ctx):
    # The directory of the package
    build_dir = ctx.build_file_path.replace("BUILD.bazel", "")

    entry_point_name = _get_bundle_name(ctx.attr.entry_point)

    bundle_name = "{label}_{bundle_name}".format(
        label = ctx.label.name,
        bundle_name = entry_point_name
    )

    rollup_outputs = [
        ctx.actions.declare_file("bundles/" + bundle_name + ".umd.js"),
        ctx.actions.declare_file("fesm2015/" + bundle_name + ".js"),
        ctx.actions.declare_file("fesm5/" + bundle_name + ".js"),
    ]

    files = []
    declarations = []

    for dep in ctx.attr.deps:
        if JSEcmaScriptModuleInfo in dep:
            files.extend(dep[JSEcmaScriptModuleInfo].sources.to_list())

        if DeclarationInfo in dep:
            files.extend(dep[DeclarationInfo].declarations.to_list())
            declarations.extend(dep[DeclarationInfo].declarations.to_list())

        if JSNamedModuleInfo in dep:
            files.extend(dep[JSNamedModuleInfo].sources.to_list())

    for file in flatten_esm5(ctx).to_list():
        # correct the destination path to be inside an esm5 folder
        dest_file_path = file.short_path.replace(build_dir + esm5_root_dir(ctx) + "/" + build_dir, "esm5/")
        dest_file = ctx.actions.declare_file(dest_file_path)
        copy_file(ctx, file, dest_file)
        files.append(dest_file)

    rollup_inputs = _filter_js(ctx.files.entry_point) + files
    rollup_globals = dict(WELL_KNOWN_GLOBALS, **ctx.attr.globals)

    rollup_externals = rollup_globals.keys()
    rollup_externals.append("tslib")

    # Create a rollup config file out of the rollup config template in the
    # tools folder. Then add the config to the inputs that it is available for
    # rollup.
    config = ctx.actions.declare_file("_%s.rollup_config.js" % ctx.label.name)
    ctx.actions.expand_template(
        template = ctx.file._rollup_config,
        output = config,
        substitutions = {
            "{base_path}": join([ctx.bin_dir.path, build_dir]),
            "{entry_point_name}": entry_point_name,
            "{bundle_name}": bundle_name,
            "'{rollup_globals}'": "{%s}" % ", ".join(["'%s': '%s'" % g for g in rollup_globals.items()]),
            "'{rollup-externals}'": "[%s]" % ", ".join(["'%s'" % e for e in rollup_externals]),

        },
    )

    rollup_inputs.append(config)

    rollup_args = ["--config", config.path]

    run_node(
        ctx = ctx,
        inputs = rollup_inputs,
        executable = "rollup_bin",
        outputs = rollup_outputs,
        arguments = rollup_args,
        mnemonic = "Rollup",
        progress_message = """
--------------------------------------------
    Creating Angular Package:
    - %s
--------------------------------------------
""" % build_dir[:-1],
    )

    return [
        DefaultInfo(files = depset(
            rollup_outputs + declarations
        ))
    ]

ng_sub_package = rule(
    implementation = _ng_sub_package_impl,
    attrs = {
        "rollup_bin": attr.label(
            doc = "Target that executes the rollup binary",
            executable = True,
            cfg = "host",
            default = "@npm//rollup/bin:rollup",
        ),
        "entry_point": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "deps": attr.label_list(
            aspects = [es5_aspect, module_mappings_aspect, node_modules_aspect],
            mandatory = True,
            doc = "The list of SubPackages that should be bundled",
        ),
        "globals": attr.string_dict(
            doc = """A dict of symbols that reference external scripts.
            The keys are variable names that appear in the program,
            and the values are the symbol to reference at runtime in a global context (UMD bundles).
            For example, a program referencing @angular/core should use ng.core
            as the global reference, so Angular users should include the mapping
            `"@angular/core":"ng.core"` in the globals.""",
            default = {},
        ),
        "_rollup_config": attr.label(
            default = Label("//tools/ng_package:rollup.config.js"),
            allow_single_file = True,
        ),
    },
)

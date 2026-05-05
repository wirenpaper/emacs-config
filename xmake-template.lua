add_rules("mode.debug")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "."})

add_requires("catch2")
set_toolchains("clang")
set_languages("cxx23")
set_policy("build.c++.modules.std", false)

local variants = {
  { suffix = "",       flags = nil },
  { suffix = "_asan",  flags = {"-fsanitize=address", "-fno-omit-frame-pointer"} },
  { suffix = "_tsan",  flags = {"-fsanitize=thread", "-fno-omit-frame-pointer"} },
  { suffix = "_ubsan", flags = {"-fsanitize=undefined"} }
}

-- Check what files actually exist in your folder right now
local has_modules = #os.files("*.cppm") > 0
local has_app     = os.isfile("main.cpp")
local has_tests   = #os.files("test_*.cpp") > 0

for _, v in ipairs(variants) do
  local mod_name  = "mod"  .. v.suffix
  local test_name = "test" .. v.suffix
  local app_name  = "prog" .. v.suffix

  -- 1. Modules (ONLY BUILDS IF *.cppm FILES EXIST!)
  if has_modules then
    target(mod_name)
    set_kind("static")
    add_files("*.cppm", {public = true})
    if v.flags then
      add_cxflags(v.flags, {force = true})
      add_ldflags(v.flags, {force = true})
    end
  end

  -- 2. The Real App (ONLY BUILDS IF main.cpp EXISTS!)
  if has_app then
    target(app_name)
    set_kind("binary")
    set_targetdir("bin")
    add_files("main.cpp")
    if has_modules then add_deps(mod_name) end -- Only link modules if they exist
    if v.flags then
      add_cxflags(v.flags, {force = true})
      add_ldflags(v.flags, {force = true})
    end
  end

  -- 3. The Tests (ONLY BUILDS IF test_*.cpp FILES EXIST!)
  if has_tests then
    target(test_name)
    set_kind("binary")
    set_targetdir("bin")
    add_packages("catch2", {links = {"Catch2Main", "Catch2"}}) 
    add_files("test_*.cpp") 
    if has_modules then add_deps(mod_name) end -- Only link modules if they exist
    if v.flags then
      add_cxflags(v.flags, {force = true})
      add_ldflags(v.flags, {force = true})
    end
  end
end

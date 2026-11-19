package ci

def compile(String target) {
    return target.trim()
}

def deploy(String env) {
    compile(env)
}

compile("core")
compile "web"
deploy("prod")

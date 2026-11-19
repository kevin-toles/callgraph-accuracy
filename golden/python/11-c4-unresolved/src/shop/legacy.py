def run(task):
    prepare_env()
    task.execute()
    return helpers_missing.compute(task)


bootstrap()

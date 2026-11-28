import sys

if __name__ == '__main__':
    if sys.argv[1:] == ['--embedded-worker']:
        from listen_app.embedded import worker_main
        worker_main()
    else:
        from listen_app.server import main
        main()

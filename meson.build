project('rpminspect-data-centos',
        version : '1.3',
        license : 'CC-BY-SA-4.0',
        meson_version : '>=0.47.0')

# Install data files
install_subdir(
    'abi',
    install_dir : get_option('datadir') + '/rpminspect'
)
install_subdir(
    'capabilities',
    install_dir : get_option('datadir') + '/rpminspect'
)
install_subdir(
    'politics',
    install_dir : get_option('datadir') + '/rpminspect'
)
install_subdir(
    'fileinfo',
    install_dir : get_option('datadir') + '/rpminspect'
)
install_subdir(
    'rebaseable',
    install_dir : get_option('datadir') + '/rpminspect'
)
install_subdir(
    'icons',
    install_dir : get_option('datadir') + '/rpminspect'
)
install_subdir(
    'security',
    install_dir : get_option('datadir') + '/rpminspect'
)

install_subdir(
    'profiles',
    install_dir : get_option('datadir') + '/rpminspect'
)

# Install the configuration file
install_data(
    sources : 'centos.yaml',
    install_dir : get_option('datadir') + '/rpminspect'
)

# Install scripts
install_data(
    sources : 'rpminspect-centos',
    install_dir : get_option('bindir'),
    install_mode : 'rwxrwxrwx'
)

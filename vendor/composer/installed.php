<?php return array(
    'root' => array(
        'name' => 'plott/plottcore-wordpress',
        'pretty_version' => '6.9.1',
        'version' => '6.9.1.0',
        'reference' => null,
        'type' => 'metapackage',
        'install_path' => __DIR__ . '/../../',
        'aliases' => array(),
        'dev' => true,
    ),
    'versions' => array(
        'johnpbloch/wordpress-core-installer' => array(
            'dev_requirement' => false,
            'replaced' => array(
                0 => '*',
            ),
        ),
        'plott/plottcore-wordpress' => array(
            'pretty_version' => '6.9.1',
            'version' => '6.9.1.0',
            'reference' => null,
            'type' => 'metapackage',
            'install_path' => __DIR__ . '/../../',
            'aliases' => array(),
            'dev_requirement' => false,
        ),
        'plott/plottcore-wordpress-no-content' => array(
            'pretty_version' => '6.33.0',
            'version' => '6.33.0.0',
            'reference' => 'f6ef2911c13f40f6948a2dd199f338d4a3f24170',
            'type' => 'wordpress-core',
            'install_path' => __DIR__ . '/../plott/plottcore-wordpress-no-content',
            'aliases' => array(),
            'dev_requirement' => false,
        ),
        'plott/plottcore-wp-installer' => array(
            'pretty_version' => '1.40.0',
            'version' => '1.40.0.0',
            'reference' => '8b0986f258f79678d84d8f8ee3713acaef2c20e9',
            'type' => 'composer-plugin',
            'install_path' => __DIR__ . '/../plott/plottcore-wp-installer',
            'aliases' => array(),
            'dev_requirement' => false,
        ),
        'wordpress/core-implementation' => array(
            'dev_requirement' => false,
            'provided' => array(
                0 => '*',
            ),
        ),
    ),
);

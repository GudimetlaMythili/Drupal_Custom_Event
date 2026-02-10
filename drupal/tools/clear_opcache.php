<?php
if (extension_loaded('opcache')) {
    opcache_reset();
    echo "✓ Opcache cleared\n";
} else {
    echo "✓ Opcache not loaded\n";
}

function pkg-verify --description 'Verify package origin + liveness; halt if unverifiable'
    if test (count $argv) -ne 1
        echo "usage: pkg-verify <pkg>" >&2
        return 64
    end
    set -l pkg $argv[1]
    if pacman -Si "$pkg" >/dev/null 2>&1
        echo "NATIVE  $pkg -> packages/*.txt"
        return 0
    end
    if paru -Si "$pkg" >/dev/null 2>&1
        echo "AUR     $pkg -> archive/pacman-foreign.txt"
        return 0
    end
    echo "UNVERIFIED $pkg (offline or dead). HALT: emit no manifest entry." >&2
    return 1
end

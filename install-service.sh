# parse options
while [ -n "$1" ]; do
	case "$1" in
		--model) export MODEL="$2"; shift;;
		--version-hub) export VERSION_HUB="$2"; shift;;
		--version-hubctl) export VERSION_HUBCTL="$2"; shift;;
		--arch) export ARCH="$2"; shift;;
		-*)
			echo "Invalid option: $1"
			exit 1
		;;
		*) break;;
	esac
	shift;
done

if [ -z "$MODEL" ]
then
	echo "Missing model"
	exit 1
fi

if [ -z "$VERSION_HUB" ]
then
	echo "Missing version hub"
	exit 1
fi

if [ -z "$VERSION_HUBCTL" ]
then
	echo "Missing version hub controller"
	exit 1
fi

if [ -z "$ARCH" ]
then
	echo "Missing arch"
	exit 1
fi

###
cd /tmp
wget "https://gist.githubusercontent.com/baohavan/1b8dccaf9d5f2201724dae8c8421b21a/raw/26a9ae797ff43ce7c447126a78394ac7f2c8d0ec/hub_installer.sh"
chmod +x hub_installer.sh
./hub_installer.sh --model "$MODEL" --version "$VERSION_HUB" --arch "$ARCH"

###
cd /tmp
wget "https://gist.githubusercontent.com/baohavan/65bf5fc1f2d44f09bcb6fb27bf0920a8/raw/f6fb5df34c62fd011ee24664127cbd25c9bf9150/hub_controller_installer.sh"
chmod +x hub_controller_installer.sh
./hub_controller_installer.sh --version "$VERSION_HUBCTL" --arch "$ARCH"

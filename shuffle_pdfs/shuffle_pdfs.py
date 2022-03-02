import os
import re
import subprocess
import sys
import time

VAR_BACK_FILENAME = "back"
VAR_FRONT_FILENAME = "front"

def shuffle(file_path, front_file, back_file, dest_file):
	abs_file_path = os.path.abspath(file_path)
	print(f"INFO. File path is {os.path.abspath(file_path)}\n")
	print(f"INFO. Shuffling: {front_file} and {back_file} into '{dest_file}'\n")
	try:
		cmd_arr = [
			"/System/Library/Automator/Combine\\ PDF\\ Pages.action/Contents/Resources/join.py",
			"--shuffle", "-o", f'"{abs_file_path}/{dest_file}"',
			f'"{abs_file_path}/{front_file}"', f'"{abs_file_path}/{back_file}"',
		]
		return " ".join(cmd_arr)
		# TODO: figure out why Python isn't running shell command + implement custom version
		# something to consider, https://docs.python.org/3/library/subprocess.html#security-considerations
		# resp = subprocess.run(cmd_arr, shell=True)
	except Exception as e:
		print(f"ERROR shuffling PDFs: {e}\n")


def get_target_filename(file_path, file_name):
	"""
	if files are named back.pdf and front.pdf, use the directory name for destination file name,
	otherwise, take the prefix title before the key names
	"""
	prefix, _, ext = file_name.partition(".")
	_, _, dir_name = file_path.rpartition("/")
	dest_filename = ""

	if prefix == VAR_BACK_FILENAME or prefix == VAR_FRONT_FILENAME:
		dest_filename = f"{dir_name.replace('.', '')}"
	else:
		dest_filename = re.sub(r"[\s+]?(back|front)$", r"", prefix)

	if os.path.exists(f"{file_path}/{dest_filename}.{ext}"):
		return f"{dest_filename} {int(time.time())}.{ext}"
	else:
		return f"{dest_filename}.{ext}"


def main():
	files_to_merge = [f"{dp}/{f}" for dp, dn, fn in os.walk(os.path.expanduser(".")) for f in fn if "back.pdf" in f]
	# using shorthand for the second loop within longhand os.walk() won't get all files recursively

	with open("merge_files.sh", "w") as merge_file_fn:
		for fp in files_to_merge[:1]:
			file_path, _, back_file = fp.rpartition("/")
			front_file = re.sub(r"(back)?\.([^.]*)$", r"front.\2", back_file)

			if not os.path.isfile(f"{file_path}/{front_file}"):
				print(f"ERROR: Could not find corresponding file for {back_file}")
				continue

			target_file = get_target_filename(file_path, back_file)

			merge_file_fn.write(shuffle(file_path, front_file, back_file, target_file) + "\n")


if __name__ == "__main__":
	main()


import sys
from jinja2 import Environment, FileSystemLoader

if len(sys.argv) != 2:
    print("Usage: python preprocess.py <num_workers>")
    sys.exit(1)

# Read the number of workers from the command-line argument
num_workers = int(sys.argv[1])

# Load the Jinja template
env = Environment(loader=FileSystemLoader("."))
template = env.get_template("docker-compose.yml.j2")

# Render the template with the provided variables
rendered_template = template.render(num_workers=num_workers)

# Save the rendered template to a file
with open("docker-compose.yml", "w") as file:
    file.write(rendered_template)

import os
import requests
import json
import subprocess
import logging


def create_dn_from_userid(userid):
    userDN = "\/C\=IT\/O\=CLOUD@CNAF\/CN\={0}@dodas-iam".format(userid)
    return userDN


def register():

    endpoint = os.environ.get("PROXY_CACHE")

    response = requests.get("http://"+endpoint+"/get_dn_map")
    try:
        response.raise_for_status()
    except requests.exceptions.HTTPError as err:
        # Whoops it wasn't a 200
        logging.error("Error in getting dn_map: %s", err)
        return response.status_code
    result = json.loads(response.content)
    logging.debug("Result: %s", result)

    user_id_map = result["userMap"]

    entries = []

    for username, userid in user_id_map:
        userDN = create_dn_from_userid(userid)
        logging.info("GSI \"^" + userDN.rstrip() + "$\"    " + username)
        entries.append("GSI \"^" + userDN.rstrip() + "$\"    " + username + "\n")

        command = "adduser {}".format(username)
        create_user = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True
        )

        _, err = create_user.communicate()

        if err:
            logging.error("failed to add user %s: %s", username, err)
        else:
            logging.info("Created user %s", username)

    with open('/home/uwdir/condormapfile', 'w+') as condor_file:
        condor_file.writelines(entries)


if __name__ == '__main__':
    logging.basicConfig(filename='/var/log/form/app.log',
                        format='[%(asctime)s][%(levelname)s][%(filename)s@%(lineno)d]->[%(message)s]',
                        level=logging.DEBUG)
    register()

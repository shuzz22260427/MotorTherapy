import requests


class ConnectionHandler(object):
    connection = None

    def __new__(cls):
        if ConnectionHandler.connection is None:
            ConnectionHandler.connection = object.__new__(cls)
        return ConnectionHandler.connection

    #Funcion que se encarga de hacer un post al servidor con los datos de los juegos
    def sendToServer(self, url, json):
        requests.post(url, json)
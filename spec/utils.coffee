#     imgflo-server - Image-processing server
#     (c) 2014 The Grid
#     imgflo-server may be freely distributed under the MIT license

url = require 'url'
child = require 'child_process'
path = require 'path'
fs = require 'fs'
crypto = require 'crypto'
querystring = require 'querystring'

rmrf = (dir) ->
    if fs.existsSync dir
        for f in fs.readdirSync dir
            f = path.join dir, f
            try
                fs.unlinkSync f
            catch e
                if e.code == 'EISDIR'
                    rmrf f
                else
                    throw e


class LogHandler
    @errors = null
    constructor: (server) ->
        @errors = []
        @server = server
        server.on 'logevent', @logEvent

    logEvent: (id, data) =>
        console.log 'LOG:', id, data if @server.verbose

        ignored = [
            'request-received'
            'serve-processed-file'
            'graph-in-cache'
            'put-into-cache'
        ]

        if id == 'process-request-end'
            if data.stderr
                for e in data.stderr.split '\n'
                    e = e.trim()
                    @errors.push e if e
            if data.err
                @errors.push data.err
        else if id == 'serve-from-cache'
            #
        else if (id.indexOf 'error') != -1
            if data.err
                @errors.push data
        else if id in ignored
            #
        else
            console.log 'WARNING: unhandled log event', id

    popErrors: () ->
        errors = (e for e in @errors)
        @errors = []
        return errors

exports.LogHandler = LogHandler

exports.compareImages = (actual, expected, timeout, callback) ->
    cmd = "./install/env.sh ./install/bin/gegl-imgcmp #{actual} #{expected}"
    options =
        timeout: timeout
    child.exec cmd, options, (error, stdout, stderr) ->
        return callback error, stderr, stdout

exports.requestFileFormat = (u) ->
    parsed = url.parse u
    graph = parsed.pathname.replace '/graph/', ''
    ext = (path.extname graph).replace '.', ''
    console.log 'requestFileFormat', u, ext
    return ext || 'jpg'

exports.formatRequest = (host, graph, params, key, secret) ->
    if key and secret
        query = '?'+querystring.stringify params
        hash = crypto.createHash 'md5'
        hash.update graph+query+secret
        token = hash.digest 'hex'
        p = "/graph/#{key}/#{token}/#{graph}"
        u = url.format { protocol: 'http:', host: host, pathname: p, search: query }
        return u
    else
        return url.format { protocol: 'http:', host: host, pathname: '/graph/'+graph, query: params }

exports.rmrf = rmrf

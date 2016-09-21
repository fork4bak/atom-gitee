LoginDialog = require './login-dialog'
CloneDialog = require './clone-dialog'
CreateDialog = require './create-dialog'
CommitDialog = require './commit-dialog'
BranchDialog = require './branch-dialog'
ProgressDialog = require './progress-dialog'
DiffDialog = require './diff-dialog'

GitFile = require './git-file'
git = require './git'

{CompositeDisposable} = require 'atom'

module.exports = GitOSC =
  loginDialog: null
  cloneDialog: null
  createDialog: null
  commitDialog: null
  branchDialog: null
  progressDialog: null
  diffDialog: null

  subscriptions: null

  private_token: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @createViews(state)

    @subscriptions.add atom.commands.add 'atom-workspace',
      'gitosc:clone-project': =>
        @clone()
      'gitosc:create-project': =>
        @create()
      'gitosc:commit-project': =>
        @commit()
      'gitosc:switch-branch': =>
        @switch()
      'gitosc:compare-project': =>
        @compare()
      'gitosc:open-repository': ->
        if itemPath = getActivePath()
          GitFile.fromPath(itemPath).openRepository()
      'gitosc:open-issues': ->
        if itemPath = getActivePath()
          GitFile.fromPath(itemPath).openIssues()
      'gitosc:open-history': ->
        if itemPath = getActivePath()
          GitFile.fromPath(itemPath).history()

  deactivate: ->
    @subscriptions.dispose()

    @loginDialog?.deactivate()
    @loginDialog = null

    @cloneDialog?.deactivate()
    @cloneDialog = null

    @createDialog?.deactivate()
    @createDialog = null

    @commitDialog?.deactivate()
    @commitDialog = null

    @branchDialog?.deactivate()
    @branchDialog = null

    @progressDialog?.deactivate()
    @progressDialog = null

    @diffDialog?.deactivate()
    @diffDialog = null

    return

  serialize: ->
    loginDialogState: @loginDialog?.serialize()
    cloneDialogState: @cloneDialog?.serialize()
    createDialogState: @createDialog?.serialize()
    commitDialogState: @commitDialog?.serialize()
    branchDialogState: @branchDialog?.serialize()
    progressDialogState: @progressDialog?.serialize()
    diffDialogState: @diffDialog?.serialize()
    return

  createViews: (state) ->
    unless @loginDialog?
      @loginDialog = new LoginDialog state.loginDialogState

    unless @cloneDialog?
      @cloneDialog = new CloneDialog state.cloneDialogState

    unless @createDialog?
      @createDialog = new CreateDialog state.createDialogState

    unless @commitDialog?
      @commitDialog = new CommitDialog state.commitDialogState

    unless @branchDialog?
      @branchDialog = new BranchDialog state.branchDialogState

    unless @progressDialog?
      @progressDialog = new ProgressDialog state.progressDialogState

    unless @diffDialog?
      @diffDialog = new DiffDialog state.diffDialogState

    return

  clone: ->
    unless @private_token?
      @loginDialog.activate (username, password, @private_token) =>
        git.username = username
        git.password = password
        @cloneDialog.activate @private_token, (path_with_namespace, clone_dir) =>
          @progressDialog.activate '拉取项目中...'
          git.clone path_with_namespace, clone_dir, (err, pro_dir) =>
            unless err
              atom.project.addPath pro_dir
            @progressDialog.deactivate()

            if err
              atom.notifications.addWarning('拉取项目代码出错！')

    else
      @cloneDialog.activate @private_token, (path_with_namespace, clone_dir) =>
        @progressDialog.activate '拉取项目中...'
        git.clone path_with_namespace, clone_dir, (err, pro_dir) =>
          unless err
            atom.project.addPath pro_dir
          @progressDialog.deactivate()

          if err
            atom.notifications.addWarning('拉取项目代码出错！')

  create: ->
    unless @private_token?
      @loginDialog.activate (username, password, @private_token) =>
        git.username = username
        git.password = password
        @createDialog.activate (pro_dir, pro_name, pro_description, pro_private) =>
          @progressDialog.activate '创建仓库中...'
          git.create @private_token, pro_dir, pro_name, pro_description, pro_private, (err) =>
            @progressDialog.deactivate()

            if err
              atom.notifications.addWarning('创建远程仓库失败！')
            else
              atom.project.addPath pro_dir

    else
      @createDialog.activate (pro_dir, pro_name, pro_description, pro_private) =>
        @progressDialog.activate '创建仓库中...'
        git.create @private_token, pro_dir, pro_name, pro_description, pro_private, (err) =>
          @progressDialog.deactivate()

          if err
            atom.notifications.addWarning('创建远程仓库失败！')
          else
            atom.project.addPath pro_dir

  commit: ->
    projectPath = getActiveProjectPath()
    unless projectPath
      atom.notifications.addWarning('无法确定当前工程！')
      return

    unless @private_token?
      @loginDialog.activate (username, password, @private_token) =>
        git.username = username
        git.password = password
        @commitDialog.activate projectPath, (pro_dir, msg) =>
          @progressDialog.activate '提交代码中...'
          git.commit pro_dir, msg, (err) =>
            @progressDialog.deactivate()

            if err
              atom.notifications.addWarning('提交代码失败！')

    else
      @commitDialog.activate projectPath, (pro_dir, msg) =>
        @progressDialog.activate '提交代码中...'
        git.commit pro_dir, msg, (err) =>
          @progressDialog.deactivate()

          if err
            atom.notifications.addWarning('提交代码失败！')

  switch: ->
    projectPath = getActiveProjectPath()
    if projectPath
      @branchDialog.activate projectPath, () ->

    else
      atom.notifications.addWarning('无法确定当前工程！')

  compare: ->
    projectPath = getActiveProjectPath()
    if projectPath
      git.diff projectPath, (err, diffs) =>
        unless err
          if diffs.length > 0
            @diffDialog.activate diffs
          else
            atom.notifications.addWarning('项目暂无修改！')
          return
        atom.notifications.addWarning('无法查看修改！')
    else
      atom.notifications.addWarning('无法确定当前工程！')

getActivePath = ->
  atom.workspace.getActivePaneItem()?.getPath?()

getActiveProjectPath = ->
  filePath = getActivePath()
  [rootDir] = atom.project.relativizePath(filePath)
  rootDir